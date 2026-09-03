# 실습 11 가이드 — postgres를 Deployment → StatefulSet으로 전환 (데이터 유지)

지금 `webapp` 프로젝트의 postgres는 Deployment로 되어있습니다. 이번 실습은 **기존 데이터(`notes` 테이블)를 하나도 잃지 않고** postgres를 StatefulSet으로 바꿔봅니다. 실제 운영 환경에서도 종종 필요한, 살아있는 데이터를 옮기는 작업이라 신중하게 순서대로 진행합니다.

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl config view --minify | grep namespace   # webapp인지 확인, 아니면 -n webapp 계속 붙이기
kubectl get pods -n webapp
kubectl get pvc -n webapp
```
postgres, adminer Pod들이 다 떠있고, `postgres-pvc`가 `Bound` 상태인지 확인하세요.

## Step 1. 지금 데이터 다시 한번 확인해두기 (안전장치)

작업 전 스냅샷 삼아 확인해둡니다.

```bash
kubectl exec -n webapp deployment/postgres-deployment -- psql -U studyuser -d studydb -c "SELECT * FROM notes;"
```

## Step 2. PV의 회수 정책을 Retain으로 바꾸기 (가장 중요한 안전장치)

7회차에서 배운 것 기억하시나요 — PVC를 지우면 기본 회수 정책(`Delete`)에 따라 실제 데이터가 담긴 PV까지 같이 삭제됩니다. 이번엔 PVC를 지웠다가 다시 만들어야 하는데, 그 사이에 데이터가 날아가면 안 되니 **먼저 정책을 `Retain`(보존)으로 바꿔둡니다.**

```bash
PVNAME=$(kubectl get pvc postgres-pvc -n webapp -o jsonpath='{.spec.volumeName}')
echo "PV 이름: $PVNAME"
kubectl patch pv $PVNAME -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
kubectl get pv $PVNAME
```
`RECLAIM POLICY` 컬럼이 `Retain`으로 바뀌었는지 확인하세요.

## Step 3. 기존 postgres Deployment 삭제

PVC를 더 이상 쓰지 않게 먼저 Deployment를 지웁니다 (Service는 그대로 둡니다 — 나중에 새로 만들 StatefulSet의 Pod도 같은 라벨을 쓸 거라 자동으로 다시 연결됩니다).

```bash
kubectl delete -f manifests/project/05-postgres-deployment.yaml
kubectl get pods -n webapp -l app=postgres
```
Pod가 사라진 것을 확인하세요.

## Step 4. 기존 PVC 삭제 (데이터는 안전함, Step 2 덕분)

```bash
kubectl delete pvc postgres-pvc -n webapp
kubectl get pv $PVNAME
```
**확인할 것**: PVC는 사라졌지만 PV는 **삭제되지 않고 `Released` 상태**로 남아있는지. Step 2에서 `Retain`으로 바꿔뒀기 때문에 실제 데이터(디스크)는 그대로 보존됩니다.

## Step 5. PV를 재사용 가능하게 만들기

`Released` 상태의 PV는 이전 PVC의 흔적(`claimRef`)이 남아있어서 그대로는 새 PVC가 붙을 수 없습니다. 이 흔적을 지워서 다시 `Available`로 만듭니다.

```bash
kubectl patch pv $PVNAME --type=json -p='[{"op": "remove", "path": "/spec/claimRef"}]'
kubectl get pv $PVNAME
```
`STATUS`가 `Available`로 바뀌었는지 확인하세요.

## Step 6. StatefulSet이 기대하는 이름으로 새 PVC 만들기

StatefulSet은 `volumeClaimTemplates`을 쓰면 Pod마다 `<템플릿이름>-<StatefulSet이름>-<번호>` 형식의 PVC를 **자동으로 만듭니다.** 우리는 그 이름을 미리 알고, **그 이름으로 PVC를 직접 만들어서 아까 그 PV에 강제로 연결**해둘 겁니다. 그러면 StatefulSet이 뜰 때 "어? 이 이름의 PVC가 이미 있네" 하고 새로 만들지 않고 그대로 재사용합니다 (실무에서 실제로 쓰이는 마이그레이션 기법입니다).

```bash
nano manifests/project/11-postgres-pvc-migrated.yaml
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-storage-postgres-0
  namespace: webapp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: __PV_NAME__
```

**중요**: `__PV_NAME__` 부분을 아까 확인한 실제 PV 이름(`echo $PVNAME`으로 나온 값, `pvc-`로 시작하는 긴 문자열)으로 바꿔서 입력하세요. `volumeName`을 명시하면 동적 생성이 아니라 그 PV에 정확히 강제로 연결됩니다.

**체크 포인트**: PVC 이름(`postgres-storage-postgres-0`)의 규칙 — `postgres-storage`는 잠시 후 만들 StatefulSet의 `volumeClaimTemplates.metadata.name`, `postgres`는 StatefulSet 이름, `0`은 첫 번째(유일한) Pod의 순번입니다.

```bash
kubectl apply -f manifests/project/11-postgres-pvc-migrated.yaml
kubectl get pvc -n webapp
```
`Bound` 상태로 바로 붙는지 확인하세요 (동적 프로비저닝 대기 없이 즉시 연결됩니다 — 이미 존재하는 PV를 지정했기 때문).

## Step 7. Headless Service 만들기

StatefulSet은 각 Pod를 개별 이름으로 접근 가능하게 하는 Headless Service가 필요합니다 (`clusterIP: None`).

```bash
nano manifests/project/12-postgres-headless-service.yaml
```
```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: webapp
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```
```bash
kubectl apply -f manifests/project/12-postgres-headless-service.yaml
```

**참고**: 기존 `postgres-service`(일반 ClusterIP)는 그대로 둡니다 — adminer는 계속 이걸로 접속하니 건드릴 필요 없습니다. 이번에 추가하는 Headless Service는 StatefulSet 전용 "관리용" Service입니다.

## Step 8. StatefulSet 만들기

```bash
nano manifests/project/13-postgres-statefulset.yaml
```
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: webapp
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
  volumeClaimTemplates:
    - metadata:
        name: postgres-storage
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

**체크 포인트**: `mountPath`/`subPath`가 기존 Deployment 때와 **정확히 동일**해야 합니다 (`/var/lib/postgresql/data`, `subPath: pgdata`) — 데이터가 저장된 실제 경로와 일치해야 postgres가 기존 데이터를 찾아냅니다.

```bash
kubectl apply -f manifests/project/13-postgres-statefulset.yaml
kubectl get pods -n webapp -l app=postgres
```

**확인할 것**: 이번엔 Pod 이름이 랜덤 해시가 아니라 정확히 **`postgres-0`**로 뜨는지! (Deployment 때는 `postgres-deployment-7bd5bf6759-c9sfb` 같은 이름이었죠.)

```bash
kubectl get pvc -n webapp
```
**확인할 것**: `postgres-storage-postgres-0`이라는 PVC가 **새로 생기지 않고**(이미 Step 6에서 만들어둔 그대로) 그냥 재사용됐는지 — `AGE`를 보면 StatefulSet을 막 적용한 시점보다 오래됐을 겁니다.

## Step 9. 데이터가 살아있는지 확인 (핵심)

```bash
kubectl exec -n webapp postgres-0 -- psql -U studyuser -d studydb -c "SELECT * FROM notes;"
```
**확인할 것**: Step 1에서 봤던 `첫번째 메모` 데이터가 그대로 나오는지. Deployment에서 StatefulSet으로 완전히 다른 종류의 오브젝트로 바꿨는데도 데이터가 안전하게 이어졌다는 걸 확인하는 순간입니다.

## Step 10. Adminer가 여전히 잘 붙는지 확인

`postgres-service`(기존 ClusterIP Service)의 selector는 `app: postgres`인데, 새 StatefulSet의 Pod도 똑같은 라벨을 쓰고 있어서 **아무것도 안 바꿔도 자동으로 연결**됩니다.

```bash
kubectl get endpoints postgres-service -n webapp
```
새 Pod(`postgres-0`)의 IP가 잡혀있는지 확인하고, 브라우저에서 `http://localhost/`로 접속해 로그인 후 `notes` 테이블이 잘 보이는지 확인하세요.

## Step 11. StatefulSet만의 특징 확인 — 고정 이름 & 개별 DNS

```bash
kubectl delete pod postgres-0 -n webapp
kubectl get pods -n webapp -l app=postgres -w
```
**확인할 것**: 새로 뜬 Pod의 이름이 여전히 `postgres-0`인지 (Deployment였다면 새 랜덤 이름이 붙었겠죠). `Ctrl+C`로 watch 종료.

Headless Service를 통한 개별 DNS 이름도 확인해보세요:
```bash
kubectl exec -n webapp deployment/adminer-deployment -- getent hosts postgres-0.postgres-headless.webapp.svc.cluster.local
```
`postgres-0`의 Pod IP가 이 긴 이름으로 정확히 해석되는지 확인하세요. 이게 StatefulSet이 제공하는 "안정적인 개별 네트워크 정체성"입니다.

## 정리 (참고)

이번 실습은 데이터를 계속 살려서 써야 하니 **정리 없이 이 상태 그대로 유지**합니다. 예전 `manifests/project/05-postgres-deployment.yaml` 파일은 더 이상 적용하지 않지만(StatefulSet으로 대체됨), 기록 삼아 지우지 않고 남겨둡니다.

## 막혔을 때 자가진단 순서
1. Step 6에서 PVC가 `Pending`이면 `volumeName`에 적은 PV 이름 오타 확인
2. Step 8에서 Pod가 `CreateContainerConfigError`면 ConfigMap/Secret 이름 재확인
3. Step 9에서 데이터가 안 보이면 `mountPath`/`subPath`가 기존 Deployment 설정과 정확히 일치하는지 재확인 — 다르면 postgres가 새 빈 디렉토리를 초기화해버려서 기존 데이터를 못 찾습니다
4. PV 상태가 이상하면 `kubectl describe pv $PVNAME`으로 Events 확인
5. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
