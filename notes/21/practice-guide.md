# 실습 21 가이드 — 5단계(마지막): 검증

전체 계획: [../17/design.md](../17/design.md) · 개념: [../concepts.md](../concepts.md) "Control Plane Taint"

이번 회차 목표: 새로 만든 2노드 kubeadm 클러스터에 Deployment+Service를 재배포해서, Pod가 실제로 두 노드에 분산 스케줄되고 노드 간 통신이 정상 동작하는 것까지 확인합니다. 이걸로 17~21회차 "클러스터 직접 구성" 프로젝트를 마무리합니다.

## 준비

```bash
multipass list   # 둘 다 Running인지
multipass shell k8s-control
kubectl get nodes
```
`k8s-control`, `k8s-worker` 둘 다 `Ready`인지 확인.

### Control Plane Taint 확인 및 제거

```bash
kubectl describe node k8s-control | grep -A3 Taints
```
`node-role.kubernetes.io/control-plane:NoSchedule`가 보일 겁니다. 워커가 1대뿐이라 이대로면 모든 Pod가 워커 하나에만 몰리니, 이번 검증을 위해 제거합니다:

```bash
kubectl taint nodes k8s-control node-role.kubernetes.io/control-plane:NoSchedule-
```
`node/k8s-control untainted` 메시지가 나오면 성공. 다시 확인:
```bash
kubectl describe node k8s-control | grep -A3 Taints
```
`<none>` 또는 taint가 안 보이면 제거된 것입니다.

## Step 1. Namespace + Deployment + Service 작성

```bash
kubectl create namespace cluster-verify
nano hello.yaml
```
아래 내용을 입력하세요. (`nginxdemos/hello`는 요청받은 자신의 Pod 이름/IP를 응답 본문에 그대로 찍어주는 가벼운 테스트용 이미지입니다 — 어느 Pod가 응답했는지 눈으로 확인하기 좋습니다.)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  namespace: cluster-verify
spec:
  replicas: 6
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hello-svc
  namespace: cluster-verify
spec:
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 80
```
저장 후:
```bash
kubectl apply -f hello.yaml
```

## Step 2. 노드 분산 확인

```bash
kubectl get pods -n cluster-verify -o wide
```
`NODE` 컬럼을 보세요 — 6개 Pod가 `k8s-control`과 `k8s-worker` 양쪽에 나뉘어 뜨는지 확인합니다. (완벽히 3:3으로 안 나뉠 수도 있습니다 — 스케줄러가 리소스 여유를 보고 배치하는 것이지 강제로 균등 분배하진 않습니다. 양쪽 노드에 **최소 1개씩**은 있는지가 핵심입니다.)

## Step 3. Service를 통한 노드 간 통신 확인

임시 테스트 Pod로 Service에 여러 번 요청을 보내서, 매번 다른 Pod(=다른 노드일 수 있음)가 응답하는지 확인합니다.

```bash
kubectl run curl-test --rm -it --image=busybox:1.36 -n cluster-verify --restart=Never -- sh
```
접속되면 그 안에서:
```sh
for i in $(seq 1 8); do wget -qO- http://hello-svc | grep -E "Server (name|address)"; echo "---"; done
exit
```
`Server address`(Pod IP)가 요청마다 바뀌는 걸 볼 수 있을 겁니다. `exit` 하면 `--rm` 옵션 덕분에 테스트 Pod는 자동 삭제됩니다.

**대조해보기**: `kubectl get pods -n cluster-verify -o wide`에서 본 Pod IP와 방금 응답에 찍힌 `Server address`를 비교해서, 실제로 `k8s-control`에 뜬 Pod와 `k8s-worker`에 뜬 Pod가 **둘 다** 응답으로 돌아오는지 확인하세요. 이게 확인되면 Calico의 노드 간 라우팅(19회차에서 배운 IP-in-IP 터널링)이 실전에서 동작한다는 최종 증거입니다.

## Step 4. 정리

검증이 끝났으면 taint를 원래대로 복구하고(프로덕션 관례를 되살리는 차원 — 우리 랩은 계속 쓸 거라 굳이 복구 안 해도 되지만, "원래 이런 게 있었다"는 걸 남기는 의미로), 테스트 리소스를 지웁니다.

```bash
kubectl delete namespace cluster-verify
```
taint를 복구하고 싶다면:
```bash
kubectl taint nodes k8s-control node-role.kubernetes.io/control-plane:NoSchedule
```
(이건 선택입니다 — 계속 실습용 클러스터로 쓸 거라 taint 없이 둬도 무방합니다. 어떻게 할지는 자유롭게 정하세요.)

## 여기서 끝나는 이유

17회차(VM 준비)부터 시작한 "클러스터 직접 구성" 프로젝트가 여기서 완주됩니다. Docker Desktop이 그동안 숨겨왔던 것들 — VM 프로비저닝, containerd 설치, control plane 부트스트랩, CNI, worker join, 노드 간 Pod 네트워킹 — 을 전부 손으로 겪어본 셈입니다.

## 막혔을 때 자가진단

1. **Pod가 전부 한쪽 노드에만 몰림**
   - taint가 제대로 제거됐는지 `kubectl describe node k8s-control | grep -A3 Taints`로 재확인
   - replicas를 늘려서(`kubectl scale deployment hello -n cluster-verify --replicas=10`) 다시 시도해볼 수도 있음
2. **`curl-test` Pod가 `ImagePullBackOff`**
   - Docker Hub 레이트 리밋일 수 있음, 잠시 후 재시도
3. **`wget`이 응답을 못 받음**
   - `kubectl get endpoints hello-svc -n cluster-verify`로 Service가 실제 Pod IP들을 잡고 있는지 확인
   - `kubectl get pods -n cluster-verify`로 Pod들이 전부 `Running`인지 확인

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요.
