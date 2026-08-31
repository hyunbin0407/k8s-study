# 실습 08 가이드 — Ingress (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

이번 실습은 지금까지와 다르게, 먼저 **Ingress Controller**라는 것을 클러스터에 설치하는 단계부터 시작합니다. Deployment/Service는 K8s에 기본 내장이지만 Ingress는 이 컨트롤러가 있어야 실제로 동작합니다.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl get pods -A | grep nginx
```
아무것도 안 나오는지 확인하세요.

## Step 1. Ingress Controller 설치하기

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
```

**참고**: 만약 이 URL이 404 등으로 실패하면, [ingress-nginx 공식 설치 문서](https://kubernetes.github.io/ingress-nginx/deploy/)에서 "Docker Desktop" 또는 "Cloud generic" 섹션의 최신 명령어를 확인해서 알려주세요 — 버전 태그가 바뀌었을 수 있습니다.

설치 후 컨트롤러가 뜰 때까지 지켜보세요 (이미지를 새로 받아와야 해서 1~2분 정도 걸릴 수 있습니다):
```bash
kubectl get pods -n ingress-nginx -w
```
`ingress-nginx-controller-...` Pod가 `1/1 Running`이 되면 `Ctrl+C`로 빠져나오세요.

Service도 확인:
```bash
kubectl get service -n ingress-nginx ingress-nginx-controller
```
**확인할 것**: `TYPE`이 `LoadBalancer`인지. `EXTERNAL-IP`는 `172.18.0.x` 같은 클러스터 내부 IP로 나올 수 있는데, 그건 신경 쓰지 않아도 됩니다 — Docker Desktop은 그 표시와 무관하게 `LoadBalancer` 타입 Service의 포트를 내부적으로 호스트의 `localhost`에 매핑해줍니다. 실제로 여는 건 항상 `localhost`입니다.

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/
```
`404`가 나오면 정상입니다 — 아직 Ingress 규칙을 하나도 안 만들어서 컨트롤러가 기본 응답(404)을 준 것뿐이고, 컨트롤러 자체는 정상 작동 중이라는 증거입니다.

## Step 2. 첫 번째 앱(nginx) 배포하기

지금까지 써온 nginx 스택을 그대로 재사용합니다.

```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl apply -f manifests/02-nginx-service.yaml
kubectl apply -f manifests/03-nginx-configmap.yaml
kubectl apply -f manifests/04-nginx-secret.yaml
kubectl get pods -l app=nginx
```
Pod 3개가 `Running`이 될 때까지 기다리세요.

## Step 3. 두 번째 앱(httpd) 배포하기

경로 기반 라우팅을 눈으로 확실히 구분하기 위해, nginx와는 다른 웹서버(Apache httpd)를 하나 더 배포합니다. httpd의 기본 페이지는 nginx와 다르게 생겨서 어느 쪽으로 연결됐는지 한눈에 구분됩니다.

```bash
nano manifests/07-app2-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
        - name: httpd
          image: httpd:latest
          ports:
            - containerPort: 80
```

```bash
nano manifests/08-app2-service.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app2-service
spec:
  selector:
    app: app2
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

적용:
```bash
kubectl apply -f manifests/07-app2-deployment.yaml
kubectl apply -f manifests/08-app2-service.yaml
kubectl get pods -l app=app2
```

## Step 4. Ingress 만들기 — 경로 기반 라우팅

`/app1`로 들어오면 nginx-service로, `/app2`로 들어오면 app2-service로 연결되는 Ingress를 만듭니다.

```bash
nano manifests/09-nginx-ingress.yaml
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /app1(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
          - path: /app2(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: app2-service
                port:
                  number: 80
```

**체크 포인트**: `rewrite-target: /$2`와 `use-regex: "true"`는 "요청 경로에서 `/app1`, `/app2` 접두어를 떼어내고 나머지만 백엔드로 전달"하기 위한 설정입니다. 이게 없으면 nginx/httpd가 `/app1`이라는 경로를 몰라서 404를 냅니다.

적용:
```bash
kubectl apply -f manifests/09-nginx-ingress.yaml
kubectl get ingress
```
`ADDRESS` 컬럼이 채워질 때까지 (`kubectl get ingress -w`로 지켜봐도 됩니다) 잠시 기다리세요.

## Step 5. 실제로 접속해서 라우팅 확인하기 (핵심)

```bash
curl -s http://localhost/app1/ | grep -i "<title>"
curl -s http://localhost/app2/
```

**확인할 것**:
- `/app1/`로 접속하면 nginx 페이지(`<title>Welcome to nginx!</title>`)가 나오는지
- `/app2/`로 접속하면 httpd 페이지(`<p>It works!</p>` 포함, nginx와 다른 마크업)가 나오는지

같은 주소(`localhost`)의 **같은 포트(80)**로 요청했는데, 경로만 다르게 줬을 뿐인데 완전히 다른 앱(다른 Deployment, 다른 Service)으로 연결된 것을 확인하는 게 이번 실습의 핵심입니다. 브라우저에서 `http://localhost/app1/`, `http://localhost/app2/`를 직접 열어봐도 좋습니다.

## Step 6. Ingress 규칙만 바꿔서 라우팅 변경해보기 (선택)

Deployment나 Service는 하나도 안 건드리고, Ingress 규칙만 수정해서 라우팅이 바뀌는 것도 확인해보세요.

```bash
nano manifests/09-nginx-ingress.yaml
```
`/app2(/|$)(.*)` 규칙의 `backend.service.name`을 `app2-service`에서 `nginx-service`로 바꿔보세요 (즉 `/app2`도 nginx로 가게).

적용 후:
```bash
kubectl apply -f manifests/09-nginx-ingress.yaml
curl -s http://localhost/app2/ | grep -i "<title>"
```
**확인할 것**: 이번엔 `/app2/`도 nginx 페이지가 나오는지 — 애플리케이션 코드나 배포는 그대로 두고, 순전히 라우팅 규칙(Ingress)만 바꿔서 트래픽 흐름을 바꿀 수 있다는 걸 확인하는 단계입니다.

## Step 7. 정리

```bash
kubectl delete -f manifests/09-nginx-ingress.yaml
kubectl delete -f manifests/07-app2-deployment.yaml
kubectl delete -f manifests/08-app2-service.yaml
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
kubectl delete -f manifests/03-nginx-configmap.yaml
kubectl delete -f manifests/04-nginx-secret.yaml
```

Ingress Controller까지 지우고 싶다면 (선택, 계속 다른 실습에서 Ingress를 또 쓸 수도 있으니 남겨둬도 무방합니다):
```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -n ingress-nginx` — Controller Pod가 안 뜨면 `describe`로 이미지 다운로드 문제인지 확인
2. `kubectl get ingress` — `ADDRESS`가 계속 비어있으면 Controller가 완전히 준비될 때까지 더 기다려보기
3. `curl`이 404를 내면 `rewrite-target`/`use-regex` 설정과 `path` 정규식을 다시 확인
4. `curl`이 아예 연결이 안 되면 `kubectl get service -n ingress-nginx ingress-nginx-controller`로 `EXTERNAL-IP`가 `localhost`인지 확인
5. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
