# 실습 04 가이드 — ConfigMap (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

클러스터가 비어있는 상태이니 기존 manifest부터 다시 적용합니다.

```bash
cd ~/Workspace/k8s-study
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl apply -f manifests/02-nginx-service.yaml
kubectl get pods -l app=nginx
```
Pod 3개가 `Running`이 될 때까지 기다린 후 다음으로 넘어가세요.

## Step 1. ConfigMap YAML 파일 만들기

`manifests/03-nginx-configmap.yaml` 파일을 nano로 새로 만들고 아래 내용을 입력하세요.

```bash
nano manifests/03-nginx-configmap.yaml
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  GREETING: "Hello from ConfigMap"
  LOG_LEVEL: "debug"
```

저장 후 적용:
```bash
kubectl apply -f manifests/03-nginx-configmap.yaml
kubectl get configmap
kubectl describe configmap nginx-config
```

**확인할 것**: `describe` 결과의 `Data` 섹션에 `GREETING`, `LOG_LEVEL` 값이 그대로 들어있는지.

## Step 2. Deployment에서 ConfigMap을 환경변수로 연결하기

`manifests/01-nginx-deployment.yaml`을 nano로 열어서, `containers:` 안 `image`/`ports` 아래에 `envFrom` 섹션을 추가하세요.

```bash
nano manifests/01-nginx-deployment.yaml
```

수정 후 파일 전체가 아래처럼 되어야 합니다 (추가되는 부분은 `envFrom` 4줄):

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
          envFrom:
            - configMapRef:
                name: nginx-config
```

**체크 포인트**: `envFrom`은 `image`, `ports`와 같은 들여쓰기 레벨(컨테이너 필드)이어야 합니다. `configMapRef.name`이 Step 1에서 만든 ConfigMap 이름(`nginx-config`)과 일치해야 함.

저장 후 적용:
```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
```

**확인할 것**: Pod 이름이 전부 바뀌었는지 — Pod 템플릿(스펙)이 변경됐으니 이것도 하나의 **롤링 업데이트**입니다 (지난 실습에서 배운 그대로, 이번엔 이미지가 아니라 `envFrom`이 추가된 것 때문에 트리거됨).

## Step 3. 환경변수가 실제로 주입됐는지 확인

```bash
kubectl get pods -l app=nginx
```
Pod 이름 하나를 복사해서:
```bash
kubectl exec -it <Pod 이름> -- env | grep -E "GREETING|LOG_LEVEL"
```

**확인할 것**: `GREETING=Hello from ConfigMap`, `LOG_LEVEL=debug`가 출력되는지.

## Step 4. ConfigMap을 수정해도 이미 떠있는 Pod엔 반영 안 되는 것 확인 (중요한 실험)

```bash
nano manifests/03-nginx-configmap.yaml
```
`LOG_LEVEL: "debug"`를 `LOG_LEVEL: "info"`로 수정 후 저장.

```bash
kubectl apply -f manifests/03-nginx-configmap.yaml
```

방금 확인했던 그 Pod에서 다시 확인해보세요 (Pod를 새로 만들지 않았습니다):
```bash
kubectl exec -it <같은 Pod 이름> -- env | grep LOG_LEVEL
```

**확인할 것**: 여전히 `LOG_LEVEL=debug`로 나오는지 — ConfigMap은 바뀌었지만 **이미 실행 중인 Pod의 환경변수는 그대로**입니다. 환경변수는 컨테이너가 시작될 때 딱 한 번 값이 고정되기 때문입니다.

## Step 5. 강제로 반영시키기 (Pod 재생성)

새로운 개념: `kubectl rollout restart` — 이미지나 설정 파일을 안 바꿔도, Deployment의 Pod들을 전부 강제로 새로 만들게 하는 명령어입니다.

```bash
kubectl rollout restart deployment/nginx-deployment
kubectl rollout status deployment/nginx-deployment
```

새로 생긴 Pod에서 다시 확인:
```bash
kubectl get pods -l app=nginx
kubectl exec -it <새 Pod 이름> -- env | grep LOG_LEVEL
```

**확인할 것**: 이번엔 `LOG_LEVEL=info`로 바뀌어 나오는지. Pod가 새로 만들어지면서 최신 ConfigMap 값을 읽어온 것입니다.

## Step 6. (선택) 볼륨 마운트 방식은 다르다는 것 맛보기

환경변수 대신 파일로 마운트하면 어떻게 다른지 궁금하면 아래를 시도해보세요 (선택 사항, 조금 더 복잡합니다).

`manifests/01-nginx-deployment.yaml`을 다시 열어서 `containers` 아래 `volumeMounts`를, `spec.template.spec` 아래(컨테이너 목록과 같은 레벨)에 `volumes`를 추가:

```yaml
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: nginx-config
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config
      volumes:
        - name: config-volume
          configMap:
            name: nginx-config
```

적용 후 파일 내용 확인:
```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
kubectl exec -it <새 Pod 이름> -- cat /etc/config/LOG_LEVEL
```
→ ConfigMap의 각 key가 `/etc/config/` 아래 개별 파일로 마운트됩니다. `info`가 출력되면 성공.

이제 ConfigMap 값을 또 바꿔보고 (`nano manifests/03-nginx-configmap.yaml`), apply 후 **Pod를 재생성하지 않고** 1분 정도 기다렸다가 다시 `cat` 해보세요:
```bash
kubectl apply -f manifests/03-nginx-configmap.yaml
# 1분 정도 대기
kubectl exec -it <같은 Pod 이름> -- cat /etc/config/LOG_LEVEL
```
**확인할 것**: Pod를 재생성 안 했는데도 파일 내용이 자동으로 갱신돼있는지 — 이게 환경변수 방식과 볼륨 마운트 방식의 핵심 차이입니다.

## Step 7. 정리

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
kubectl delete -f manifests/03-nginx-configmap.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -l app=nginx` — Pod가 `CreateContainerConfigError` 등으로 안 뜨면 ConfigMap 이름 오타 의심
2. `kubectl describe pod <이름>` — Events에서 구체적 에러 확인
3. `kubectl get configmap nginx-config -o yaml` — ConfigMap 내용이 의도한 대로인지 확인
4. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.