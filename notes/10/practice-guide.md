# 실습 10 가이드 — 미니 프로젝트 구현: webapp (PostgreSQL + Adminer)

설계 문서: [../09/design.md](../09/design.md)

지금까지 배운 8개 개념을 조합해서, 실제 DB를 가진 2-tier 앱을 처음부터 배포합니다. 이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

```bash
cd ~/Workspace/k8s-study
mkdir -p manifests/project
kubectl get pods -n ingress-nginx
```
`ingress-nginx-controller-...`가 `Running`인지 확인하세요 (8회차에서 설치해둔 것을 재사용합니다 — 이번엔 새로 설치할 필요 없습니다).

## Step 1. Namespace 만들기

```bash
nano manifests/project/01-namespace.yaml
```
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webapp
```
```bash
kubectl apply -f manifests/project/01-namespace.yaml
kubectl get namespace webapp
```

앞으로 이 프로젝트의 모든 명령어는 **`-n webapp`을 붙여서** 실행합니다. 매번 치기 귀찮으면 아래처럼 현재 컨텍스트의 기본 Namespace를 바꿔둘 수도 있습니다 (6회차에서 배운 것의 실전 활용):
```bash
kubectl config set-context --current --namespace=webapp
```
이후로는 `-n webapp` 없이도 명령어가 자동으로 `webapp`을 대상으로 합니다. (되돌리려면 `kubectl config set-context --current --namespace=default`)

## Step 2. postgres 설정값 (ConfigMap) 만들기

```bash
nano manifests/project/02-postgres-configmap.yaml
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: webapp
data:
  POSTGRES_DB: studydb
  POSTGRES_USER: studyuser
```
```bash
kubectl apply -f manifests/project/02-postgres-configmap.yaml
```

## Step 3. postgres 비밀번호 (Secret) 만들기

```bash
nano manifests/project/03-postgres-secret.yaml
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: webapp
type: Opaque
stringData:
  POSTGRES_PASSWORD: studypassword123
```
```bash
kubectl apply -f manifests/project/03-postgres-secret.yaml
```

## Step 4. postgres 데이터 저장 공간 (PVC) 만들기

```bash
nano manifests/project/04-postgres-pvc.yaml
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: webapp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```
```bash
kubectl apply -f manifests/project/04-postgres-pvc.yaml
kubectl get pvc -n webapp
```
`Pending`이면 정상입니다 (7회차에서 배운 것처럼 Pod가 생겨야 PV가 만들어집니다).

## Step 5. postgres Deployment + Service 만들기

```bash
nano manifests/project/05-postgres-deployment.yaml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-deployment
  namespace: webapp
spec:
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
          image: postgres:16
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
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
```

**체크 포인트**: `subPath: pgdata`를 쓴 이유 — postgres는 데이터 디렉토리가 완전히 비어있지 않으면(예: `lost+found` 폴더가 있으면) 초기화에 실패하는 경우가 있어서, PVC 최상위가 아니라 그 안의 `pgdata`라는 하위 폴더에만 데이터를 저장하도록 지정한 것입니다.

```bash
nano manifests/project/06-postgres-service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: webapp
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  type: ClusterIP
```

적용:
```bash
kubectl apply -f manifests/project/05-postgres-deployment.yaml
kubectl apply -f manifests/project/06-postgres-service.yaml
kubectl get pods -n webapp -l app=postgres
kubectl get pvc -n webapp
```
Pod가 `Running`이 되고, PVC가 `Bound`로 바뀌는지 확인하세요.

## Step 6. adminer 설정값 (ConfigMap) 만들기

adminer는 자체적으로 로그인 화면에서 DB 서버 주소를 입력받지만, 미리 기본값으로 채워두면 편합니다.

```bash
nano manifests/project/07-adminer-configmap.yaml
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: adminer-config
  namespace: webapp
data:
  ADMINER_DEFAULT_SERVER: postgres-service
```
```bash
kubectl apply -f manifests/project/07-adminer-configmap.yaml
```

**체크 포인트**: `postgres-service`라는 **Service 이름**을 그대로 DB 주소로 씀 — Pod IP가 아니라 Service 이름을 쓰는 이유, 기억나시나요? (2회차 Service 개념 복습: Pod가 재생성돼도 Service 이름은 고정이라서.)

## Step 7. adminer Deployment + Service 만들기

```bash
nano manifests/project/08-adminer-deployment.yaml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adminer-deployment
  namespace: webapp
spec:
  replicas: 2
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
```
```bash
nano manifests/project/09-adminer-service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: adminer-service
  namespace: webapp
spec:
  selector:
    app: adminer
  sessionAffinity: ClientIP
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
```

**체크 포인트**: `sessionAffinity: ClientIP`를 넣어둔 이유 — adminer는 로그인 세션을 자기가 떠있는 Pod의 로컬 디스크에 저장하는 앱이라, replicas가 2개 이상이면 요청이 매번 다른 Pod로 갈 때 로그인이 계속 끊기는 문제가 생깁니다. 다만 **이 설정은 Service를 직접 거치는 트래픽에만 적용**되고, 우리가 Step 8에서 만들 Ingress는 성능을 위해 Service를 거치지 않고 각 Pod에 직접 연결하기 때문에 이 설정만으로는 Ingress를 통한 접속의 세션 문제가 해결되지 않습니다 (실제로 겪게 됩니다 — Step 9에서 자세히 다룸). 그래도 클러스터 내부에서 Service를 직접 거쳐 접근하는 경우를 위해 남겨둡니다.

적용:
```bash
kubectl apply -f manifests/project/08-adminer-deployment.yaml
kubectl apply -f manifests/project/09-adminer-service.yaml
kubectl get pods -n webapp -l app=adminer
```
Pod 2개가 `Running`이 될 때까지 기다리세요.

## Step 8. Ingress로 외부 노출하기

```bash
nano manifests/project/10-ingress.yaml
```
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: webapp
  annotations:
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "adminer_route"
    nginx.ingress.kubernetes.io/session-cookie-expires: "3600"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: adminer-service
                port:
                  number: 8080
```

**체크 포인트 (중요)**: `nginx.ingress.kubernetes.io/affinity: "cookie"` 관련 어노테이션이 이번 실습에서 제일 중요한 부분입니다. Step 7에서 Service에 `sessionAffinity: ClientIP`를 넣어도 Ingress는 Service를 거치지 않고 Pod에 직접 연결하기 때문에 소용이 없다고 했었죠 — 그래서 **Ingress Controller 자체가 지원하는 sticky session 기능**을 대신 써야 합니다. 이 어노테이션은 nginx-ingress가 응답에 `adminer_route`라는 쿠키를 심어서, 같은 브라우저(같은 쿠키)는 항상 같은 Pod로 보내도록 강제합니다. (이 어노테이션 없이 `replicas: 2`인 adminer 앞에 Ingress를 두면, 로그인 직후 페이지를 이동할 때마다 다른 Pod로 요청이 튀면서 로그인이 계속 풀리거나 "잘못된 CSRF 토큰입니다" 경고가 반복해서 뜹니다 — 실제로 겪기 쉬운 문제라 처음부터 넣어두는 것입니다.)

```bash
kubectl apply -f manifests/project/10-ingress.yaml
kubectl get ingress -n webapp
```

## Step 9. 브라우저로 접속해서 DB 다뤄보기 (핵심)

브라우저에서 `http://localhost/`를 열어보세요. Adminer 로그인 화면이 나올 겁니다.

| 필드 | 값 |
|---|---|
| System | PostgreSQL |
| Server | `postgres-service` (자동으로 채워져 있을 겁니다) |
| Username | `studyuser` |
| Password | `studypassword123` |
| Database | `studydb` |

로그인 후:
1. 왼쪽 메뉴에서 **"Create table"**을 클릭해 테이블 생성 화면으로 진입
2. 화면 맨 위 **"테이블 이름:" 옆의 빈 입력창**에 `notes`라고 입력하세요 — 헷갈리기 쉬운 부분인데, "테이블 이름"이라는 라벨과 그 아래 실제로 테이블을 생성하는 **"Create table" 버튼**이 이름이 비슷해서 착각하기 쉽습니다. 버튼이 아니라 그 위의 입력창에 이름을 적는 것입니다.
3. 아래 컬럼 표에 두 행 추가: `id`(형: `integer`, AI 체크), `content`(형: `text`)
4. 맨 아래 **저장(Save) 버튼**까지 눌러서 완료
5. 테이블 생성 후, `notes` 테이블 → **"New item"**으로 데이터 몇 줄 직접 입력하고 저장

**체크 포인트**: 로그인 후 화면을 오래 열어둔 채로 있다가 제출하면 "잘못된 CSRF 토큰입니다" 경고가 뜰 수 있습니다. 이건 폼을 불러온 시점의 보안 토큰이 만료돼서 그런 것이니, 페이지를 하드 리프레시(`Cmd+Shift+R`)하고 로그인부터 다시 한 뒤 너무 시간 끌지 말고 이어서 진행하면 됩니다.

**여기까지 되면**: 우리가 만든 K8s 리소스들이 실제로 살아있는 DB로 동작하고 있다는 걸 확인한 것입니다.

## Step 10. PV 검증 — postgres Pod를 지워도 데이터가 남는지 (7회차 실험 재현)

```bash
kubectl get pods -n webapp -l app=postgres
kubectl delete pod <postgres Pod 이름> -n webapp
kubectl get pods -n webapp -l app=postgres
```
새 Pod가 뜬 후, 브라우저를 새로고침해서 Adminer로 다시 로그인 → 아까 만든 테이블/데이터가 그대로 남아있는지 확인하세요.

## Step 11. 스케일링 검증 — adminer를 늘려도 같은 DB를 보는지 (3회차 복습)

```bash
kubectl scale deployment/adminer-deployment --replicas=4 -n webapp
kubectl get pods -n webapp -l app=adminer
```
지금 쓰던 브라우저 탭은 Step 8에서 설정한 sticky session 쿠키 때문에 계속 같은 Pod로만 연결됩니다 — 그래서 새로고침해도 항상 같은 Pod가 응답합니다. **다른 Pod로도 잘 연결되는지** 확인하려면 시크릿(사생활 보호) 모드 창을 새로 열어서 `http://localhost/`에 다시 로그인해보세요 — 새 쿠키를 받으니 다른 Pod로 연결될 가능성이 높습니다.

**확인할 것**: 어느 Pod로 연결되든 항상 같은 데이터(아까 만든 `notes` 테이블과 데이터)가 보이는지. adminer 자체는 상태를 각 Pod 로컬에 갖고 있지만(그래서 sticky session이 필요했죠), 실제 데이터는 전부 postgres Pod 하나에만 저장되기 때문에 어느 adminer Pod를 거치든 같은 결과를 봅니다.

## Step 12. (선택) 정리

```bash
kubectl delete namespace webapp
```
Namespace 하나만 지우면 안의 모든 리소스(Deployment, Service, ConfigMap, Secret, PVC, Ingress)가 전부 함께 정리됩니다 (6회차에서 배운 것 그대로). Ingress Controller는 계속 남겨둡니다.

## 트러블슈팅 노트 — 세션/로그인 관련

이번 실습에서 실제로 겪기 쉬운 문제와 원인을 정리합니다.

| 증상 | 원인 | 해결 |
|---|---|---|
| 테이블을 만들었는데 이름이 `Create table`로 되어있고 컬럼도 없음 | "테이블 이름" 입력창이 아니라 그 아래 버튼을 이름으로 착각해서 제출 | 테이블 삭제 후, 입력창 위치를 다시 확인하고 재생성 |
| 로그인했다가 페이지 이동하면 다시 로그인 화면으로 튕김 | adminer `replicas: 2` 이상 + Ingress가 요청마다 다른 Pod로 분산 + 세션은 Pod 로컬에 저장 | Ingress에 `nginx.ingress.kubernetes.io/affinity: cookie` 어노테이션 추가 (Step 8 참고) |
| "잘못된 CSRF 토큰입니다" 경고 | 위와 같은 원인, 또는 폼을 오래 열어두고 늦게 제출 | 위와 동일 + 페이지 하드 리프레시 후 빠르게 재시도 |
| Service에 `sessionAffinity: ClientIP`를 넣었는데도 안 고쳐짐 | Ingress Controller는 Service(kube-proxy)를 거치지 않고 Pod에 직접 연결 — Service 레벨 설정이 Ingress 트래픽에는 적용 안 됨 | Service가 아니라 **Ingress 레벨**에서 sticky session을 설정해야 함 (Step 8) |

## 막혔을 때 자가진단 순서
1. `kubectl get pods -n webapp` — postgres/adminer Pod 상태 확인
2. `kubectl describe pod <이름> -n webapp` — Events에서 구체적 에러 확인
3. `kubectl logs <postgres Pod 이름> -n webapp` — DB 초기화 실패 시 로그에 원인이 나옵니다
4. Adminer 로그인이 안 되면 `kubectl get configmap adminer-config -n webapp -o yaml`, `kubectl get secret postgres-secret -n webapp -o yaml`로 값 재확인
5. 로그인이 자꾸 풀리거나 CSRF 경고가 뜨면 위 "트러블슈팅 노트" 표부터 확인
6. `kubectl logs -n webapp deployment/adminer-deployment`로 adminer 요청 로그를 보면서, 같은 요청이 여러 Pod에 번갈아 찍히는지 확인해보면 세션 문제인지 아닌지 판단에 도움이 됩니다
5. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
