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
  ports:
    - port: 8080
      targetPort: 8080
  type: ClusterIP
```

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
1. 왼쪽 메뉴에서 새 테이블(`Create table`) 만들기 — 예: `notes`라는 테이블에 `id`(정수, 자동증가), `content`(텍스트) 컬럼 추가
2. 테이블에 데이터 몇 줄 직접 입력(`New item`)
3. 저장까지 확인

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
브라우저를 여러 번 새로고침해보세요 (매번 다른 adminer Pod로 요청이 갈 수 있습니다 — Service의 로드밸런싱). **확인할 것**: 어느 Pod가 응답하든 항상 같은 데이터(아까 만든 테이블)가 보이는지. adminer 자체는 상태를 안 갖고 있고(stateless), 데이터는 전부 postgres 하나에만 있기 때문입니다.

## Step 12. (선택) 정리

```bash
kubectl delete namespace webapp
```
Namespace 하나만 지우면 안의 모든 리소스(Deployment, Service, ConfigMap, Secret, PVC, Ingress)가 전부 함께 정리됩니다 (6회차에서 배운 것 그대로). Ingress Controller는 계속 남겨둡니다.

## 막혔을 때 자가진단 순서
1. `kubectl get pods -n webapp` — postgres/adminer Pod 상태 확인
2. `kubectl describe pod <이름> -n webapp` — Events에서 구체적 에러 확인
3. `kubectl logs <postgres Pod 이름> -n webapp` — DB 초기화 실패 시 로그에 원인이 나옵니다
4. Adminer 로그인이 안 되면 `kubectl get configmap adminer-config -n webapp -o yaml`, `kubectl get secret postgres-secret -n webapp -o yaml`로 값 재확인
5. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
