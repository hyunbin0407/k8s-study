# 실습 05 가이드 — Secret (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

클러스터가 비어있는 상태이니 기존 manifest부터 다시 적용합니다. (지난 실습에서 Deployment에 ConfigMap 연결까지 해뒀던 상태라 ConfigMap도 같이 적용합니다.)

```bash
cd ~/Workspace/k8s-study
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl apply -f manifests/02-nginx-service.yaml
kubectl apply -f manifests/03-nginx-configmap.yaml
kubectl get pods -l app=nginx
```
Pod 3개가 `Running`이 될 때까지 기다린 후 다음으로 넘어가세요.

## Step 1. Secret YAML 파일 만들기 (`stringData` 사용)

`manifests/05-nginx-secret.yaml` 파일을 nano로 새로 만드세요.

```bash
nano manifests/05-nginx-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nginx-secret
type: Opaque
stringData:
  DB_PASSWORD: password123
  API_KEY: my-secret-api-key
```

**체크 포인트**: `stringData`를 쓰면 평문 그대로 적어도 됩니다 — Kubernetes가 저장할 때 자동으로 base64 인코딩해줍니다.

저장 후 적용:
```bash
kubectl apply -f manifests/05-nginx-secret.yaml
kubectl get secret
```

## Step 2. 실제로 base64로 저장됐는지 확인하기

```bash
kubectl get secret nginx-secret -o yaml
```

**확인할 것**: `data:` 아래 `DB_PASSWORD`, `API_KEY` 값이 `password123`이 아니라 이상한 문자열(base64)로 보이는지. YAML엔 분명 `stringData`로 평문을 적었는데, 저장된 건 `data`(base64) 형태로 바뀌어 있을 겁니다.

원문으로 직접 디코딩해보세요:
```bash
kubectl get secret nginx-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo
```
→ `password123`이 나오면, base64는 암호화가 아니라 그냥 인코딩이라는 걸(디코딩 명령 한 줄이면 누구나 원문을 볼 수 있음) 직접 확인한 것입니다.

## Step 3. Deployment에서 Secret을 환경변수로 연결하기

`manifests/01-nginx-deployment.yaml`을 nano로 열어서, 기존 `envFrom` 아래에 `secretRef` 항목을 하나 더 추가하세요.

```bash
nano manifests/01-nginx-deployment.yaml
```

`envFrom` 부분이 아래처럼 되도록 수정 (기존 `configMapRef`는 그대로 두고, `secretRef` 추가):

```yaml
          envFrom:
            - configMapRef:
                name: nginx-config
            - secretRef:
                name: nginx-secret
```

**체크 포인트**: `envFrom`은 리스트라서 항목을 여러 개 넣을 수 있습니다. `-` 들여쓰기가 `configMapRef`와 같은 레벨이어야 합니다.

저장 후 적용:
```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
```
Pod 스펙이 또 바뀌었으니 이번에도 롤링 업데이트가 발생할 겁니다.

## Step 4. 컨테이너 안에서 값이 평문으로 들어오는지 확인

```bash
kubectl get pods -l app=nginx
```
새 Pod 이름 하나를 복사해서:
```bash
kubectl exec -it <Pod 이름> -- env | grep -E "DB_PASSWORD|API_KEY"
```

**확인할 것**: `DB_PASSWORD=password123`, `API_KEY=my-secret-api-key`처럼 **평문 그대로** 나오는지. 클러스터에 저장될 땐 base64였지만, 컨테이너 프로세스 안에서는 일반 환경변수와 똑같이 평문으로 보입니다 — Secret이 "저장 형태"만 다를 뿐, 앱 입장에서는 ConfigMap과 사용법이 동일하다는 걸 확인하는 단계입니다.

## Step 5. `describe`에서는 값이 안 보이는 것 확인

```bash
kubectl describe deployment nginx-deployment | grep -A5 "Environment Variables from"
```

**확인할 것**: `nginx-secret  Secret  Optional: false`처럼 Secret 이름만 나오지, 그 안의 `DB_PASSWORD`나 `API_KEY` 값 자체는 어디에도 출력되지 않습니다. `describe`나 `get -o yaml` 같은 일반 조회 명령으로는 값이 노출되지 않게 설계되어 있다는 것 — 이게 ConfigMap 대신 Secret을 쓰는 이유 중 하나입니다.

## Step 6. 정리

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
kubectl delete -f manifests/03-nginx-configmap.yaml
kubectl delete -f manifests/05-nginx-secret.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -l app=nginx` — `CreateContainerConfigError`가 뜨면 Secret 이름 오타 의심
2. `kubectl describe pod <이름>` — Events에서 구체적 에러 확인
3. `kubectl get secret nginx-secret -o yaml` — Secret 내용이 의도한 대로인지 확인
4. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.