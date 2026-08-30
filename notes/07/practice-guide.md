# 실습 07 가이드 — PersistentVolume (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl get pods -A | grep nginx
```
아무것도 안 나오는지 확인하세요.

이번 실습의 Deployment는 ConfigMap/Secret도 계속 참조하므로, 먼저 그것들부터 배포해둡니다.
```bash
kubectl apply -f manifests/03-nginx-configmap.yaml
kubectl apply -f manifests/04-nginx-secret.yaml
```

## Step 1. PersistentVolumeClaim(PVC) YAML 만들기

`manifests/06-nginx-pvc.yaml` 파일을 nano로 새로 만드세요.

```bash
nano manifests/06-nginx-pvc.yaml
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

저장 후 적용:
```bash
kubectl apply -f manifests/06-nginx-pvc.yaml
kubectl get pvc
```

**확인할 것**: `STATUS`가 `Pending`으로 나올 겁니다 — 에러가 아닙니다! Docker Desktop의 스토리지(`local-path-provisioner`)는 **실제로 Pod가 그 PVC를 쓰려고 할 때까지 PV 생성을 미룹니다** (`WaitForFirstConsumer` 방식). 아직 아무 Pod도 이 PVC를 안 썼으니 `Pending`이 정상입니다.

## Step 2. Deployment에 PVC 연결하고 replicas를 1로 줄이기

이번 실습은 replica가 여러 개면 헷갈릴 수 있어서, 지난번에 배운 스케일링을 활용해 **임시로 1개로 줄여서** 진행합니다.

```bash
nano manifests/01-nginx-deployment.yaml
```

`spec.replicas`를 `3`에서 `1`로 바꾸고, `containers` 안 `volumeMounts`에 항목을 하나 추가, `spec.template.spec.volumes`에도 항목을 하나 추가하세요. 최종적으로 파일 전체가 아래처럼 되어야 합니다:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
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
            - secretRef:
                name: nginx-secret
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config
            - name: html-storage
              mountPath: /usr/share/nginx/html
      volumes:
        - name: config-volume
          configMap:
            name: nginx-config
        - name: html-storage
          persistentVolumeClaim:
            claimName: nginx-pvc
```

**체크 포인트**: `/usr/share/nginx/html`은 nginx가 웹페이지 파일을 읽어오는 기본 경로입니다. 여기에 PVC를 마운트하면, 우리가 그 안에 넣는 파일이 곧 nginx가 보여주는 웹페이지가 됩니다.

저장 후 적용:
```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
kubectl get pvc
```

**확인할 것**: Pod가 1개로 줄었는지, 그리고 이번엔 PVC의 `STATUS`가 `Bound`로 바뀌었는지 (Pod가 실제로 PVC를 쓰려고 하니 그제서야 PV가 만들어지고 연결된 것).

```bash
kubectl get pv
```
→ PV가 자동으로 하나 생성된 것도 확인해보세요 (우리가 PV YAML을 만든 적이 없는데도 생겼죠 — `local-path-provisioner`가 대신 만들어준 것).

## Step 3. 볼륨에 직접 파일을 써보기

지금 마운트한 디렉토리(`/usr/share/nginx/html`)는 비어있어서, nginx 기본 페이지 대신 다른 게 보일 수 있습니다. 커스텀 페이지를 하나 써넣어 보겠습니다.

```bash
kubectl get pods -l app=nginx
```
Pod 이름을 복사해서:
```bash
kubectl exec -it <Pod 이름> -- sh -c 'echo "<h1>Hello from PersistentVolume</h1>" > /usr/share/nginx/html/index.html'
```

확인:
```bash
kubectl exec -it <Pod 이름> -- cat /usr/share/nginx/html/index.html
```
Service를 통해 접속해서도 확인해보세요:
```bash
kubectl apply -f manifests/02-nginx-service.yaml
kubectl exec -it <Pod 이름> -- curl -s http://nginx-service
```
`Hello from PersistentVolume`이 나오면 성공입니다.

## Step 4. Pod를 삭제해서 데이터가 살아남는지 확인 (핵심 실험)

```bash
kubectl delete pod <Pod 이름>
kubectl get pods -l app=nginx
```
Self-healing으로 새 Pod가 자동 생성될 겁니다 (지난번에 배운 것 그대로). 새 Pod 이름을 확인하세요.

```bash
kubectl exec -it <새 Pod 이름> -- cat /usr/share/nginx/html/index.html
```

**확인할 것**: Pod는 완전히 새로 만들어졌는데(새 이름, 새 컨테이너), 방금 썼던 `Hello from PersistentVolume` 내용이 그대로 남아있는지! 이게 PersistentVolume의 핵심입니다 — Pod의 생명주기와 데이터의 생명주기가 분리되어 있다는 것.

## Step 5. Deployment 자체를 지워도 데이터가 남는지 확인

이번엔 더 과감하게, Deployment 전체를 삭제했다가 다시 만들어봅니다.

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl get pvc
```
**확인할 것**: Deployment(따라서 Pod도)는 사라졌는데, PVC(`nginx-pvc`)는 `Bound` 상태 그대로 남아있는지.

다시 배포:
```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
```
새로 생긴 Pod에서 확인:
```bash
kubectl exec -it <새 Pod 이름> -- cat /usr/share/nginx/html/index.html
```
**확인할 것**: Deployment를 통째로 지웠다 다시 만들었는데도 `Hello from PersistentVolume`이 여전히 남아있는지 — 데이터는 PVC에 종속되어 있지, Deployment나 Pod에 종속된 게 아니라는 걸 확실하게 확인하는 단계입니다.

## Step 6. PVC를 지우면 실제로 데이터가 사라지는 것 확인 (선택)

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete pvc nginx-pvc
kubectl get pv
```
**확인할 것**: PVC를 지우니 연결되어 있던 PV도 같이 사라지는지 (`ReclaimPolicy: Delete`가 기본값이라서 그렇습니다 — `kubectl get storageclass`로 확인했던 그 정책입니다).

## Step 7. 정리

`manifests/01-nginx-deployment.yaml`의 `replicas`를 다시 `3`으로, `volumeMounts`/`volumes`의 `html-storage` 관련 부분을 삭제해서 원래대로 되돌려놓으세요 (다음 실습에서 헷갈리지 않게).

```bash
nano manifests/01-nginx-deployment.yaml
```

나머지 리소스도 정리:
```bash
kubectl delete -f manifests/01-nginx-deployment.yaml 2>/dev/null
kubectl delete -f manifests/02-nginx-service.yaml
kubectl delete -f manifests/03-nginx-configmap.yaml
kubectl delete -f manifests/04-nginx-secret.yaml
kubectl delete pvc nginx-pvc 2>/dev/null
```

## 막혔을 때 자가진단 순서
1. `kubectl get pvc` — `Pending`이 계속되면 `kubectl describe pvc nginx-pvc`로 Events 확인 (StorageClass 문제일 수 있음)
2. `kubectl get pv` — PV가 안 생기면 Pod가 실제로 스케줄링됐는지(`kubectl get pods`) 먼저 확인 (`WaitForFirstConsumer`라 Pod가 있어야 PV가 생김)
3. `kubectl describe pod <이름>` — `FailedMount` 등의 Events 확인
4. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
