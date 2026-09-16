# 실습 22 가이드 — NetworkPolicy

개념: [../concepts.md](../concepts.md) "NetworkPolicy"

이번 회차 목표: 기본적으로 전부 열려있는 Pod 간 통신을, NetworkPolicy로 "특정 라벨을 가진 Pod에서 오는 트래픽만" 허용하도록 막아보고, 실제로 막히는 것/허용되는 것을 `curl`로 직접 확인합니다.

## 준비

```bash
multipass list   # 둘 다 Running인지
multipass shell k8s-control
kubectl get nodes
kubectl create namespace netpol-lab
```

## Step 1. backend 배포

```bash
nano backend.yaml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: netpol-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      role: backend
  template:
    metadata:
      labels:
        role: backend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: netpol-lab
spec:
  selector:
    role: backend
  ports:
  - port: 80
    targetPort: 80
```
```bash
kubectl apply -f backend.yaml
kubectl get pods -n netpol-lab
```
`Running` 2개 확인.

## Step 2. (정책 적용 전) 기준선 확인 — 전부 열려있음을 확인

라벨이 다른 테스트 Pod 두 개로 각각 `backend-svc`에 접속을 시도합니다. **아직 NetworkPolicy가 없으니 둘 다 성공해야 정상**입니다.

```bash
kubectl run frontend-test --image=busybox:1.36 --labels="role=frontend" -n netpol-lab --restart=Never -it --rm -- wget -qO- --timeout=5 http://backend-svc
```
→ nginx 기본 페이지(`<title>Welcome to nginx!</title>` 등) HTML이 출력되면 성공.

```bash
kubectl run stranger-test --image=busybox:1.36 --labels="role=stranger" -n netpol-lab --restart=Never -it --rm -- wget -qO- --timeout=5 http://backend-svc
```
→ 이것도 지금은 똑같이 성공해야 합니다 (라벨이 뭐든 상관없이 전부 열려있는 기본 상태).

## Step 3. NetworkPolicy 적용 — `role: frontend`만 허용

```bash
nano netpol.yaml
```
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      role: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
```
```bash
kubectl apply -f netpol.yaml
kubectl get networkpolicy -n netpol-lab
```

## Step 4. (정책 적용 후) 다시 테스트 — 이번엔 갈려야 함

Step 2와 똑같은 두 명령을 **다시** 실행합니다.

```bash
kubectl run frontend-test --image=busybox:1.36 --labels="role=frontend" -n netpol-lab --restart=Never -it --rm -- wget -qO- --timeout=5 http://backend-svc
```
**예상**: 여전히 성공 (`role=frontend`는 허용 목록에 있으므로).

```bash
kubectl run stranger-test --image=busybox:1.36 --labels="role=stranger" -n netpol-lab --restart=Never -it --rm -- wget -qO- --timeout=5 http://backend-svc
```
**예상**: 이번엔 **`timed out` 에러로 실패**해야 합니다 — `role=frontend`가 아닌 트래픽은 이제 backend에 도달 못 함. 이게 NetworkPolicy가 실제로 패킷을 막고 있다는 증거입니다.

## Step 5. (선택) egress도 막아보기

`role: frontend` Pod 자체는 바깥 어디로든 나갈 수 있는 상태입니다. egress까지 제한해보고 싶다면:

```bash
nano netpol-egress.yaml
```
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-allow-backend-only
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      role: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          role: backend
  - to:      # DNS 조회는 항상 허용해야 함 — 없으면 서비스 이름 자체를 못 찾음
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
```
```bash
kubectl apply -f netpol-egress.yaml
```
이제 `role: frontend` Pod는 `role: backend` 말고는 (DNS 제외) 어디로도 못 나갑니다. `kubectl run other-svc-test ... --labels="role=frontend" ... -- wget -qO- --timeout=5 http://kubernetes.default.svc.cluster.local` 같은 걸로 apiserver 접근이 막히는지 확인해볼 수 있습니다.

## Step 6. 정리

```bash
kubectl delete namespace netpol-lab
```

## 막혔을 때 자가진단

1. **정책 적용 전인데도 `stranger-test`가 실패함**
   - `kubectl get networkpolicy -n netpol-lab`로 이전에 만든 정책이 남아있지 않은지 확인
2. **정책 적용 후에도 `stranger-test`가 계속 성공함**
   - `kubectl describe networkpolicy backend-allow-frontend -n netpol-lab`로 `podSelector`/`ingress.from`이 의도대로 들어갔는지 확인
   - Calico Pod가 정상인지 `kubectl get pods -n kube-system -l k8s-app=calico-node` 확인 (CNI가 죽어있으면 정책이 강제 안 될 수 있음)
3. **`frontend-test`까지 실패함**
   - `netpol.yaml`의 `matchLabels`(`role: frontend`)와 `kubectl run`의 `--labels` 값이 정확히 일치하는지 확인 (오타 흔함)
4. **`wget`이 즉시 실패가 아니라 5초 정확히 걸린 후 timeout으로 실패**
   - 이게 정상입니다 — 패킷이 명시적으로 거부되는 게 아니라 "조용히 버려지는"(drop) 방식이라 타임아웃까지 기다려야 실패로 확인됨

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요.
