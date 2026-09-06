# 실습 14 가이드 — Helm으로 webapp 프로젝트 패키징하기

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

이번 실습은 지금 `webapp` Namespace에서 돌고 있는 실제 프로젝트는 건드리지 않습니다. 대신 **완전히 새로운 Namespace(`webapp-helm`)에 Helm으로 같은 앱을 처음부터 패키지 배포**해봅니다 — 그래야 마음껏 설치/삭제/롤백을 연습해도 기존 데이터(`notes` 테이블 등)에 영향이 없습니다.

## Step 1. Helm 설치

```bash
brew install helm
helm version
```
버전 정보가 나오면 설치 성공입니다.

## Step 2. Chart 뼈대 만들기

```bash
cd ~/Workspace/k8s-study
mkdir -p helm/webapp-chart/templates
```

```bash
nano helm/webapp-chart/Chart.yaml
```
```yaml
apiVersion: v2
name: webapp-chart
description: PostgreSQL + Adminer 2-tier 앱 (k8s-study 9~13회차 학습 내용을 패키징)
version: 0.1.0
appVersion: "1.0"
```

```bash
nano helm/webapp-chart/values.yaml
```
```yaml
postgres:
  image: postgres:16
  dbName: studydb
  dbUser: studyuser
  dbPassword: studypassword123
  storage: 1Gi

adminer:
  image: adminer:latest
  replicas: 4
  cpuRequest: 20m
  cpuLimit: 100m

ingress:
  className: nginx
  path: /helm
```

**체크 포인트**: `values.yaml`이 바로 이 Chart의 "설정 다이얼"입니다. 여기 적힌 값들이 잠시 후 만들 템플릿 안의 `{{ .Values.xxx }}` 자리에 그대로 채워집니다.

## Step 3. 템플릿 작성하기 — postgres 관련

지금까지 `manifests/project/`에 썼던 YAML들을 템플릿 형태로 다시 씁니다. 고정값이었던 부분을 `{{ .Values.xxx }}`나 `{{ .Release.Namespace }}`로 바꾸는 게 핵심입니다.

```bash
nano helm/webapp-chart/templates/postgres-configmap.yaml
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: {{ .Release.Namespace }}
data:
  POSTGRES_DB: {{ .Values.postgres.dbName | quote }}
  POSTGRES_USER: {{ .Values.postgres.dbUser | quote }}
```

```bash
nano helm/webapp-chart/templates/postgres-secret.yaml
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: {{ .Release.Namespace }}
type: Opaque
stringData:
  POSTGRES_PASSWORD: {{ .Values.postgres.dbPassword | quote }}
```

```bash
nano helm/webapp-chart/templates/postgres-headless-service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: {{ .Release.Namespace }}
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

```bash
nano helm/webapp-chart/templates/postgres-service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: {{ .Release.Namespace }}
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP
```

```bash
nano helm/webapp-chart/templates/postgres-statefulset.yaml
```
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: {{ .Release.Namespace }}
spec:
  serviceName: postgres-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: {{ .Values.postgres.image }}
          ports:
            - containerPort: 5432
          envFrom:
            - configMapRef:
                name: postgres-config
            - secretRef:
                name: postgres-secret
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
              subPath: pgdata
  volumeClaimTemplates:
    - metadata:
        name: postgres-storage
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: {{ .Values.postgres.storage }}
```

**체크 포인트**: `{{ .Release.Namespace }}`는 나중에 `helm install`할 때 `--namespace` 옵션으로 지정하는 값이 자동으로 들어가는 자리입니다. YAML 안에 Namespace 이름을 하드코딩하지 않아도 됩니다.

## Step 4. 템플릿 작성하기 — adminer 관련

```bash
nano helm/webapp-chart/templates/adminer-configmap.yaml
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: adminer-config
  namespace: {{ .Release.Namespace }}
data:
  ADMINER_DEFAULT_SERVER: postgres-service
```

```bash
nano helm/webapp-chart/templates/adminer-deployment.yaml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adminer-deployment
  namespace: {{ .Release.Namespace }}
spec:
  replicas: {{ .Values.adminer.replicas }}
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
          image: {{ .Values.adminer.image }}
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: adminer-config
          resources:
            requests:
              cpu: {{ .Values.adminer.cpuRequest | quote }}
            limits:
              cpu: {{ .Values.adminer.cpuLimit | quote }}
```

```bash
nano helm/webapp-chart/templates/adminer-service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: adminer-service
  namespace: {{ .Release.Namespace }}
spec:
  selector:
    app: adminer
  sessionAffinity: ClientIP
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
```

## Step 5. 템플릿 작성하기 — Ingress

10회차에서 배운 sticky session 교훈(Service의 `sessionAffinity`는 Ingress엔 안 먹히고, Ingress 레벨 어노테이션이 필요했던 것)을 이번엔 처음부터 반영합니다. 그리고 8회차 방식대로 경로(`/helm`)로 접근 가능하게 만들어서, 기존 `webapp` 프로젝트의 Ingress(`/` 전체)와 겹치지 않게 합니다.

```bash
nano helm/webapp-chart/templates/ingress.yaml
```
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: {{ .Release.Namespace }}
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "adminer_route"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - http:
        paths:
          - path: "{{ .Values.ingress.path }}(/|$)(.*)"
            pathType: ImplementationSpecific
            backend:
              service:
                name: adminer-service
                port:
                  number: 8080
```

## Step 6. 렌더링 미리보기 & 문법 검증

실제로 설치하기 전에, 템플릿이 값과 잘 합쳐져서 올바른 YAML이 되는지 미리 확인합니다.

```bash
helm lint helm/webapp-chart
helm template webapp-release helm/webapp-chart
```
`helm lint`는 문법/구조 문제를 검사하고, `helm template`은 실제로 렌더링된 최종 YAML 전체를 화면에 출력해줍니다. `{{ .Values.postgres.dbName }}` 같은 자리가 전부 실제 값(`studydb` 등)으로 채워져 나오는지 눈으로 확인해보세요.

## Step 7. 설치하기 (핵심)

지금까지는 파일을 하나씩 `kubectl apply` 했었죠. 이번엔 명령어 딱 하나로 전체 스택을 설치합니다.

```bash
helm install webapp-release helm/webapp-chart --namespace webapp-helm --create-namespace
```

**확인할 것**: `--create-namespace` 덕분에 `webapp-helm`이라는 새 Namespace가 자동으로 만들어지고, 그 안에 리소스가 전부 한 번에 생성됩니다.

```bash
helm list -n webapp-helm
kubectl get all -n webapp-helm
kubectl get ingress -n webapp-helm
```

Pod들이 `Running`이 될 때까지 기다린 후, 브라우저에서 `http://localhost/helm/`로 접속해보세요. Adminer 로그인 화면이 뜨는지 확인하세요 (System: PostgreSQL, Server: `postgres-service`, Username: `studyuser`, Password: `studypassword123`, Database: `studydb`).

## Step 8. Values만 바꿔서 업그레이드하기 (핵심)

템플릿 파일은 하나도 안 건드리고, 명령줄에서 값만 바꿔서 재배포해봅니다.

```bash
kubectl get pods -n webapp-helm -l app=adminer   # 지금 4개인지 확인
helm upgrade webapp-release helm/webapp-chart --namespace webapp-helm --set adminer.replicas=2
kubectl get pods -n webapp-helm -l app=adminer   # 2개로 줄었는지 확인
```

**확인할 것**: YAML 파일을 하나도 안 고쳤는데 `--set` 옵션 하나로 replicas가 바뀌었습니다. 3회차에서 배운 "선언적 관리"가 Helm에서는 값(Values) 레벨로 한 단계 더 추상화된 것입니다.

## Step 9. 롤백하기

```bash
helm history webapp-release -n webapp-helm
```
지금까지의 리비전 이력(REVISION 1: 최초 설치, REVISION 2: replicas=2로 업그레이드)이 보일 겁니다.

```bash
helm rollback webapp-release 1 -n webapp-helm
kubectl get pods -n webapp-helm -l app=adminer
```
**확인할 것**: replicas가 다시 4개로 돌아왔는지. 2회차의 `kubectl rollout undo`가 Deployment 하나만 되돌렸다면, `helm rollback`은 이 Chart에 포함된 **모든 리소스를 그 시점의 상태로 통째로** 되돌립니다.

## Step 10. 정리

```bash
helm uninstall webapp-release -n webapp-helm
kubectl get all -n webapp-helm
```
**확인할 것**: 명령어 딱 한 줄로 Chart에 포함된 모든 리소스(ConfigMap, Secret, StatefulSet, Deployment, Service, Ingress 전부)가 한꺼번에 삭제되는지 — 지금까지 리소스마다 `kubectl delete -f`를 여러 번 쳐야 했던 것과 비교됩니다.

```bash
kubectl delete namespace webapp-helm
```
`helm uninstall`은 리소스만 지우고 Namespace 껍데기는 안 지우므로, 마지막으로 Namespace까지 정리합니다. (기존 `webapp` Namespace의 프로젝트는 전혀 영향받지 않았습니다 — 계속 확인해보세요: `kubectl get pods -n webapp`)

## 막혔을 때 자가진단 순서
1. `helm lint helm/webapp-chart` — 템플릿 문법 오류를 가장 먼저 잡아줌
2. `helm template webapp-release helm/webapp-chart`로 렌더링 결과를 직접 눈으로 확인 — `{{ }}` 자리가 이상하게 남아있으면 `values.yaml`의 키 이름 오타 의심
3. `helm install`이 실패하면 `kubectl get events -n webapp-helm --sort-by=.lastTimestamp`로 최근 이벤트 확인
4. Ingress로 접속이 안 되면 `kubectl get ingress -n webapp-helm`으로 `ADDRESS`가 채워졌는지, 기존 `webapp` 프로젝트의 Ingress와 경로가 겹치지 않는지 확인
5. `helm rollback`이 예상과 다르면 `helm history webapp-release -n webapp-helm`으로 리비전 번호를 다시 확인

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
