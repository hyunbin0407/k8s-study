# 실습 12 가이드 — HPA (자동 스케일링, 직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

이번 실습은 8회차(Ingress Controller 설치)와 비슷하게, 먼저 **metrics-server**라는 컴포넌트를 클러스터에 설치하는 것부터 시작합니다.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl config view --minify | grep namespace   # webapp인지 확인
kubectl get pods -n webapp
```
postgres(`postgres-0`), adminer(4개) 전부 살아있는지 확인하세요.

## Step 1. metrics-server 설치

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get pods -n kube-system -l k8s-app=metrics-server -w
```
`Ctrl+C`로 빠져나온 뒤 상태를 확인해보세요:
```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server
```

**높은 확률로 `CrashLoopBackOff` 또는 `Running`인데 준비가 안 된 상태일 겁니다.** Docker Desktop 같은 로컬 클러스터에서는 metrics-server가 각 노드(kubelet)의 인증서를 검증하려다가 실패하는 경우가 흔합니다. 로그로 확인해보세요:
```bash
kubectl logs -n kube-system -l k8s-app=metrics-server --tail=10
```
`x509: certificate signed by unknown authority` 같은 메시지가 보이면 예상한 그대로입니다.

## Step 2. metrics-server가 로컬 인증서를 신뢰하도록 설정

운영 클러스터라면 이 옵션을 함부로 켜면 안 되지만(보안 검증을 끄는 것이므로), 학습용 로컬 클러스터에서는 `--kubelet-insecure-tls` 옵션으로 이 검증을 건너뛰게 할 수 있습니다.

```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

Pod가 재시작되면서 정상화되는지 확인:
```bash
kubectl get pods -n kube-system -l k8s-app=metrics-server -w
```
`Running`이 되면 `Ctrl+C`. 실제로 지표를 잘 수집하는지 확인 (설치 직후엔 1분 정도 걸릴 수 있습니다):
```bash
kubectl top nodes
kubectl top pods -n webapp
```
각 Pod의 CPU/메모리 사용량이 숫자로 나오면 성공입니다.

## Step 3. adminer Deployment에 CPU 요청량(requests) 추가

HPA가 "사용률(%)"을 계산하려면 기준값이 있어야 합니다. 지금 adminer-deployment는 `resources`가 아예 없어서(`resources: {}`) HPA를 걸 수 없습니다.

```bash
nano manifests/project/08-adminer-deployment.yaml
```

`containers` 안에 `resources` 섹션을 추가해서 파일 전체가 아래처럼 되도록 수정하세요:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adminer-deployment
  namespace: webapp
spec:
  replicas: 4
  selector:
    matchLabels:
      app: adminer
  template:
    metadata:
      labels:
        app: adminer
    spec:
      containers:
        - name: adminer
          image: adminer:latest
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: adminer-config
          resources:
            requests:
              cpu: "20m"
            limits:
              cpu: "100m"
```

**체크 포인트**: `requests.cpu: "20m"`은 "20 milliCPU" = CPU 코어의 2%를 요청한다는 뜻입니다. 일부러 아주 작게 잡았습니다 — 이래야 조금만 부하를 줘도 "요청량 대비 사용률"이 금방 100%를 넘어서 오토스케일링이 빠르게 눈에 보이기 때문입니다. `limits.cpu`는 이 컨테이너가 아무리 바빠도 이 이상은 못 쓰게 막는 상한선입니다.

저장 후 적용 (Pod 스펙이 바뀌었으니 롤링 업데이트가 발생합니다):
```bash
kubectl apply -f manifests/project/08-adminer-deployment.yaml
kubectl get pods -n webapp -l app=adminer
kubectl top pods -n webapp -l app=adminer
```

## Step 4. HPA 만들기

```bash
nano manifests/project/14-adminer-hpa.yaml
```
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: adminer-hpa
  namespace: webapp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: adminer-deployment
  minReplicas: 1
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```
```bash
kubectl apply -f manifests/project/14-adminer-hpa.yaml
kubectl get hpa -n webapp
```

**확인할 것**: `TARGETS` 컬럼이 `<unknown>/50%`로 나올 수 있습니다 — 지표가 아직 안정적으로 수집되기 전이라 그렇습니다. 30초~1분 정도 후 다시 확인해서 실제 퍼센트(`예: 3%/50%`)로 바뀌는지 보세요.

## Step 5. 부하를 줘서 실제로 자동 확장되는지 확인 (핵심)

클러스터 안에서 adminer에 계속 요청을 퍼붓는 작은 Pod를 하나 띄워서 부하를 만듭니다.

**터미널 A** — HPA 상태를 실시간 관찰:
```bash
kubectl get hpa -n webapp -w
```

**터미널 B** — 부하 생성용 임시 Pod 실행:
```bash
kubectl run load-generator -n webapp --image=busybox --restart=Never -- \
  sh -c "for i in $(seq 1 8); do (while true; do wget -q -O- http://adminer-service:8080/ > /dev/null; done) & done; sleep 300"
```
이 명령은 8개의 병렬 반복문으로 5분간 계속 adminer에 요청을 보냅니다.

터미널 A에서 지켜보세요: `TARGETS`의 사용률(%)이 점점 올라가고, 일정 시간(보통 1~2분 이내) 안에 `REPLICAS` 숫자가 자동으로 늘어나는지 확인하세요. `kubectl get pods -n webapp -l app=adminer`로도 Pod 개수가 실제로 늘어나는 걸 볼 수 있습니다.

## Step 6. 부하 제거 후 다시 줄어드는지 확인

```bash
kubectl delete pod load-generator -n webapp
```
부하가 사라진 뒤에도 계속 `kubectl get hpa -n webapp -w`로 지켜보세요. **확인할 것**: 사용률이 떨어진 뒤 바로 줄지 않고, **몇 분 정도 기다렸다가** Pod 개수가 줄어드는지 (HPA는 너무 자주 늘렸다 줄였다 하는 걸(스래싱) 막기 위해 축소는 일부러 천천히 반영합니다 — 기본 대기 시간이 5분입니다).

## Step 7. 정리 (선택)

```bash
kubectl delete -f manifests/project/14-adminer-hpa.yaml
```
replicas는 HPA가 마지막으로 맞춰둔 숫자로 남아있을 텐데, 원래 개수(4)로 되돌리고 싶으면:
```bash
kubectl scale deployment/adminer-deployment --replicas=4 -n webapp
```
metrics-server는 다른 실습에서도 유용하니 지우지 않고 남겨둬도 됩니다.

## 막혔을 때 자가진단 순서
1. `kubectl get pods -n kube-system -l k8s-app=metrics-server` — 안 뜨면 `describe`/`logs`로 원인 확인
2. `kubectl top pods -n webapp`가 계속 에러면 metrics-server가 아직 안정화 안 된 것, 1~2분 더 대기
3. `kubectl get hpa -n webapp`의 `TARGETS`가 계속 `<unknown>`이면 `kubectl describe hpa adminer-hpa -n webapp`로 Events 확인
4. 스케일이 안 늘면 부하 생성 Pod가 실제로 도는지 `kubectl logs load-generator -n webapp` 확인, `requests.cpu` 값이 너무 크게 잡히지 않았는지 재확인

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
