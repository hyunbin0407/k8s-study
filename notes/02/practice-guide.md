# 실습 02 가이드 — 롤링 업데이트 & 롤백 (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

지난번 실습 후 리소스를 정리해서 클러스터가 비어있는 상태입니다. 기존 manifest를 다시 적용하는 것부터 시작합니다.

```bash
cd ~/Workspace/k8s-study
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl apply -f manifests/02-nginx-service.yaml
kubectl get pods -l app=nginx
```
Pod 3개가 `Running` 상태가 될 때까지 기다린 후 다음으로 넘어가세요.

## Step 1. 현재 이미지 버전 확인하기

```bash
kubectl get deployment nginx-deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
```
`nginx:latest`가 출력될 겁니다. (지난 실습에서 이렇게 지정했었죠.)

버전을 명확히 비교해보기 위해, 먼저 **특정 버전으로 고정**해두겠습니다.

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.25
kubectl rollout status deployment/nginx-deployment
```
`successfully rolled out`이 뜨면 완료. (이것도 사실 방금 하나의 롤링 업데이트였습니다 — latest → 1.25)

## Step 2. 진짜 롤링 업데이트 실행하며 실시간 관찰하기

**터미널 탭을 두 개** 준비하세요.

**탭 A** — 아래 명령어로 Pod 목록을 실시간 관찰 (계속 실행되는 상태로 둡니다):
```bash
kubectl get pods -l app=nginx -w
```
`-w`는 watch 옵션. 상태가 바뀔 때마다 새 줄이 계속 출력됩니다.

**탭 B** — 새 버전으로 업데이트 실행:
```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.26
```

탭 A 화면에서 일어나는 일을 관찰하세요:
- 새 이름의 Pod가 하나씩 `Pending` → `ContainerCreating` → `Running`으로 뜨는 것
- 그와 거의 동시에 기존 Pod 중 하나가 `Terminating`으로 사라지는 것
- 전체적으로 항상 2~3개의 Pod는 `Running` 상태를 유지하는 것 (완전히 다 죽는 순간이 없음)

관찰이 끝나면 탭 A에서 `Ctrl + C`로 watch 종료.

## Step 3. 결과 확인하기

```bash
kubectl rollout status deployment/nginx-deployment
kubectl get pods -l app=nginx
kubectl describe deployment nginx-deployment | grep -i image
```

**확인할 것**
- Pod 이름이 이전과 달라졌는지 (새 ReplicaSet에서 생성된 새 Pod들)
- 이미지가 `nginx:1.26`으로 바뀌었는지
- 여전히 Pod가 3개인지 (replicas 수는 그대로 유지)

ReplicaSet 이력도 확인해보세요:
```bash
kubectl get replicaset -l app=nginx
```
→ 예전 ReplicaSet(들)이 `DESIRED 0`으로 남아있고, 최신 ReplicaSet만 `DESIRED 3`인 걸 볼 수 있습니다. 이게 롤백을 가능하게 하는 "기록"입니다.

## Step 4. 배포 이력 확인하기

```bash
kubectl rollout history deployment/nginx-deployment
```
지금까지 몇 번 리비전(revision)이 있었는지 나옵니다 (latest→1.25→1.26 이렇게 세 번 변경했으니 리비전이 여러 개 있을 것).

## Step 5. 롤백 해보기

방금 올린 `1.26`을 취소하고 바로 이전 버전(`1.25`)으로 되돌려봅니다.

```bash
kubectl rollout undo deployment/nginx-deployment
kubectl rollout status deployment/nginx-deployment
```

확인:
```bash
kubectl describe deployment nginx-deployment | grep -i image
```
→ 이미지가 다시 `nginx:1.25`로 돌아왔는지 확인하세요. 롤백도 내부적으로는 "이전 버전으로의 롤링 업데이트"라서 이번에도 무중단으로 진행됩니다.

## Step 6. (선택) 일부러 잘못된 이미지로 배포해서 실패/롤백 경험해보기

실무에서 자주 겪는 상황: 오타난 이미지 태그를 배포해버리는 경우.

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:this-tag-does-not-exist
kubectl rollout status deployment/nginx-deployment --timeout=30s
```
→ 30초 안에 완료 안 되고 타임아웃 날 겁니다. 새 Pod가 `ImagePullBackOff` 상태로 멈춰있는 걸 확인하세요:
```bash
kubectl get pods -l app=nginx
```
**중요한 포인트**: 이 상황에서도 서비스는 안 죽습니다! 기존 정상 Pod들은 그대로 유지되고, 새 Pod만 뜨지 못하고 대기 중인 상태이기 때문 (`maxUnavailable` 기본값 덕분).

정상으로 되돌리기:
```bash
kubectl rollout undo deployment/nginx-deployment
kubectl rollout status deployment/nginx-deployment
```

## Step 7. 정리 (선택)

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl rollout status deployment/nginx-deployment` — 멈춰있다면 원인 파악 필요
2. `kubectl get pods -l app=nginx` — `ImagePullBackOff`, `ErrImagePull` 등 비정상 상태 확인
3. `kubectl describe pod <이름>` — Events에서 구체적 에러 메시지 확인
4. 꼬였다 싶으면 언제든 `kubectl rollout undo deployment/nginx-deployment`로 직전 상태 복귀

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.