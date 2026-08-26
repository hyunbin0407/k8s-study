# 실습 01 가이드 — Deployment + Service로 nginx 배포하기 (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비
```bash
cd ~/Workspace/k8s-study
```

## Step 1. Deployment YAML 파일 만들기

`manifests/01-nginx-deployment.yaml` 파일을 에디터(VS Code 등)로 새로 만들고 아래 내용을 입력하세요.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

**체크 포인트**
- `replicas: 3` → Pod를 몇 개 유지할지
- `selector.matchLabels`와 `template.metadata.labels`가 **반드시 같은 값**(`app: nginx`)이어야 함 — 다르면 에러 발생
- `image`는 어떤 컨테이너 이미지를 쓸지 지정 (Docker Hub의 공식 nginx 이미지)

## Step 2. Service YAML 파일 만들기

`manifests/02-nginx-service.yaml` 파일을 새로 만들고 아래 내용을 입력하세요.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

**체크 포인트**
- `selector: app: nginx` → 위 Deployment의 `labels: app: nginx`와 **똑같아야** 연결됨
- `port`는 Service가 노출하는 포트, `targetPort`는 컨테이너 내부 실제 포트

## Step 3. 클러스터에 적용하기

```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl apply -f manifests/02-nginx-service.yaml
```

`created`라는 메시지가 뜨면 성공입니다.

## Step 4. 상태 확인하기

아래 명령어를 하나씩 입력하면서 결과를 살펴보세요.

```bash
kubectl get deployment nginx-deployment
kubectl get replicaset -l app=nginx
kubectl get pods -l app=nginx -o wide
kubectl get service nginx-service
```

**확인할 것**
- Deployment 하나가 ReplicaSet 하나를, ReplicaSet이 Pod 3개를 자동으로 만들었는지
- Pod마다 IP(`10.244.x.x`)가 다른지
- Service는 고정된 `CLUSTER-IP` 하나를 가지고 있는지

추가로 이런 것도 해보세요:
```bash
kubectl describe pod <위에서 나온 Pod 이름 하나>
```
→ Pod의 상세 정보(이벤트, 이미지, 상태 등)를 볼 수 있습니다.

```bash
kubectl logs <Pod 이름>
```
→ 해당 Pod(nginx)의 로그를 볼 수 있습니다.

## Step 5. Self-healing 확인하기

Pod 하나를 일부러 지워보고, 자동으로 복구되는지 확인합니다.

```bash
kubectl get pods -l app=nginx
```
위 목록에서 Pod 이름 하나를 복사한 다음:

```bash
kubectl delete pod <복사한 Pod 이름>
kubectl get pods -l app=nginx -o wide
```

**확인할 것**: 삭제한 Pod는 사라지고, 몇 초 안에 새 이름/새 IP를 가진 Pod가 자동으로 생겨서 여전히 3개가 유지되는지.

## Step 6. Service로 접속해보기

```bash
kubectl port-forward service/nginx-service 8080:80
```
→ 이 명령은 **터미널을 점유**합니다 (계속 실행 중인 상태). 새 터미널 탭을 하나 더 열어서 아래를 실행하세요.

```bash
curl http://localhost:8080
```
→ nginx의 기본 환영 페이지 HTML이 출력되면 성공! 브라우저에서 `http://localhost:8080` 을 직접 열어봐도 됩니다.

확인 후, port-forward를 실행했던 터미널에서 `Ctrl + C`로 종료하세요.

## Step 7. 정리 (선택)

실습이 끝나면 리소스를 지워서 클러스터를 깨끗하게 유지할 수 있습니다.

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -l app=nginx` — Pod가 `Running`이 아니라면?
2. `kubectl describe pod <이름>` — 맨 아래 `Events` 섹션에서 원인 확인 (이미지 다운로드 실패, 스케줄링 실패 등)
3. `kubectl logs <이름>` — 컨테이너 자체 에러 확인
4. Service로 접속이 안 되면 `kubectl get endpoints nginx-service` — 연결된 Pod가 있는지 확인 (없으면 selector/label 오타 의심)

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.