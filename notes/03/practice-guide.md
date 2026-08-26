# 실습 03 가이드 — 스케일링 (직접 해보기)

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

## Step 1. 수동으로 늘려보기 (`kubectl scale`)

```bash
kubectl scale deployment/nginx-deployment --replicas=5
kubectl get pods -l app=nginx
```

**확인할 것**
- Pod가 3개 → 5개로 늘었는지
- 새로 생긴 Pod 2개는 **이름 접미사가 기존 Pod들과 같은 ReplicaSet 소속**인지 (`kubectl get replicaset -l app=nginx`로 확인 — 롤링 업데이트 때와 달리 ReplicaSet이 새로 안 생기고 하나만 있을 것)

```bash
kubectl get replicaset -l app=nginx
```

## Step 2. 수동으로 줄여보기

```bash
kubectl scale deployment/nginx-deployment --replicas=2
kubectl get pods -l app=nginx -w
```
`-w`로 실시간 관찰하면서, 5개 중 어떤 Pod들이 `Terminating`되는지 지켜보세요. 확인되면 `Ctrl + C`로 종료.

**확인할 것**: 남은 Pod가 정확히 2개인지, 그리고 삭제된 게 딱히 "가장 오래된 것"이나 "가장 최근 것"이라는 규칙 없이 K8s가 알아서 선택했다는 점 (관심 있으면 AGE를 비교해봐도 재밌음).

## Step 3. YAML 파일로 스케일링 (선언적 방식)

실무에서는 `kubectl scale`보다 YAML 파일의 `replicas` 값을 고쳐서 `kubectl apply`하는 방식을 더 선호합니다. 코드로 관리되고 이력이 git에 남기 때문.

`manifests/01-nginx-deployment.yaml`을 에디터(nano)로 열어서 `replicas: 3`을 `replicas: 4`로 바꾸세요.

```bash
nano manifests/01-nginx-deployment.yaml
```
`replicas:` 줄을 찾아서 숫자만 `4`로 수정 후 저장 (nano: `Ctrl+O` → Enter → `Ctrl+X`).

```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
```

**확인할 것**: Pod가 2개 → 4개로 늘었는지.

## Step 4. `kubectl scale`로 바꾼 값과 YAML 파일이 다르면?

방금 Step 1~2에서 `kubectl scale`로 명령줄에서 직접 개수를 바꿨었죠. 그런데 YAML 파일 안의 `replicas` 값은 그대로 `3`이었습니다 (Step 3에서 4로 고치기 전까지).

이런 상황을 한번 만들어서 관찰해보세요:

```bash
kubectl scale deployment/nginx-deployment --replicas=7
kubectl get pods -l app=nginx
```
→ 7개로 늘어난 것 확인.

이제 YAML 파일 내용은 그대로 둔 채(방금 4로 고쳐뒀던 상태) 다시 apply 해보세요:

```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl get pods -l app=nginx
```

**확인할 것**: 7개였던 Pod가 다시 YAML에 적힌 숫자(`4`)로 돌아오는지.

> 이게 바로 **선언적 관리의 핵심**입니다 — `kubectl scale`처럼 명령어로 즉석에서 바꾼 값은 "임시" 상태고, YAML(코드)에 적힌 값이 "진짜 원하는 상태"로 취급됨. `apply`를 다시 하는 순간 코드에 적힌 값으로 되돌아갑니다. 그래서 실무에서는 급할 때 아니면 `scale` 명령어보다 YAML을 고쳐서 apply하는 방식을 씁니다.

## Step 5. (선택) HPA 맛보기 — 개념만 확인

자동 스케일링은 CPU 사용량 등 리소스 지표(metrics-server)가 필요해서 지금 환경(Docker Desktop)에서는 바로 되지 않을 수 있습니다. 명령어만 참고로 확인해보세요 (에러 나도 정상):

```bash
kubectl autoscale deployment/nginx-deployment --min=2 --max=6 --cpu-percent=50
kubectl get hpa
```
`<unknown>`이 떠도 정상입니다 — metrics-server가 없어서 CPU 사용률을 못 읽는 것뿐. 개념만 확인하고 삭제하세요:
```bash
kubectl delete hpa nginx-deployment
```

## Step 6. 정리

먼저 YAML 파일을 원래대로(`replicas: 3`) 되돌려놓으세요 (다음에 헷갈리지 않게).

```bash
nano manifests/01-nginx-deployment.yaml
```
`replicas: 4` → `replicas: 3`으로 수정 후 저장.

```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -l app=nginx` — 개수가 예상과 다르면?
2. `kubectl get replicaset -l app=nginx` — ReplicaSet의 `DESIRED`/`CURRENT` 값 비교
3. `kubectl describe deployment nginx-deployment` — 최근 이벤트 확인
4. 뭔가 꼬였으면 `kubectl apply -f manifests/01-nginx-deployment.yaml`로 YAML 기준 상태로 되돌리기

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
