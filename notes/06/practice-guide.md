# 실습 06 가이드 — Namespace (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl get pods -A | grep nginx
```
아무것도 안 나오는지 확인하세요 (지난 실습에서 정리 완료된 상태).

## Step 1. Namespace 만들기

`manifests/05-dev-namespace.yaml` 파일을 nano로 새로 만드세요.

```bash
nano manifests/05-dev-namespace.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

저장 후 적용:
```bash
kubectl apply -f manifests/05-dev-namespace.yaml
kubectl get namespace
```

**확인할 것**: `dev`라는 이름의 Namespace가 목록에 추가됐는지. `default`, `kube-system`, `kube-public`, `local-path-storage` 등 원래 있던 것들도 같이 보일 겁니다.

## Step 2. `dev` Namespace에 nginx 스택 전체 배포하기

지금까지 써온 manifest들을 그대로 재사용하되, `-n dev` 옵션으로 **`dev` Namespace에** 적용합니다 (YAML 파일 자체는 전혀 수정하지 않습니다).

```bash
kubectl apply -f manifests/01-nginx-deployment.yaml -n dev
kubectl apply -f manifests/02-nginx-service.yaml -n dev
kubectl apply -f manifests/03-nginx-configmap.yaml -n dev
kubectl apply -f manifests/04-nginx-secret.yaml -n dev
kubectl get pods -n dev
```

Pod 3개가 `Running`이 될 때까지 기다리세요. (만약 안 뜨면 ConfigMap/Secret도 `dev`에 같이 있어야 하니 위 4개 명령을 순서대로 다 실행했는지 확인해보세요.)

## Step 3. 같은 이름으로 `default` Namespace에도 배포하기

이번엔 `-n` 옵션 없이(=`default` Namespace) 완전히 **동일한 이름**으로 또 배포해봅니다.

```bash
kubectl apply -f manifests/01-nginx-deployment.yaml
kubectl apply -f manifests/02-nginx-service.yaml
kubectl apply -f manifests/03-nginx-configmap.yaml
kubectl apply -f manifests/04-nginx-secret.yaml
kubectl get pods
```

**확인할 것**: `nginx-deployment`라는 같은 이름의 Deployment가 `dev`와 `default` 양쪽에 동시에 존재하는데도 에러 없이 둘 다 잘 만들어졌는지.

```bash
kubectl get pods -A -l app=nginx
```
`NAMESPACE` 컬럼을 보면서, 같은 이름의 Pod들이 서로 다른 Namespace에 나뉘어 있는 걸 확인하세요.

## Step 4. Namespace를 안 겹치게 조회/조작하기

```bash
kubectl get deployment                 # default 것만 나옴 (Namespace 미지정 시 default가 기본)
kubectl get deployment -n dev          # dev 것만 나옴
kubectl get deployment -A              # 전체 다 나옴
```

**확인할 것**: `-n`을 안 주면 항상 `default`만 보인다는 것. 이게 지금까지 실습에서 `-n` 없이도 잘 됐던 이유입니다 (계속 `default`에서만 작업해왔던 것).

## Step 5. Namespace 간 통신 실험 (핵심)

`default`에 있는 Pod 안에서 Service에 접근해보면서, 이름만으로 접근했을 때 **어느 쪽으로 연결되는지** 확인합니다.

```bash
kubectl get pods -l app=nginx    # default의 Pod 이름 확인
```
Pod 이름 하나를 복사해서:
```bash
kubectl exec -it <default Pod 이름> -- curl -s http://nginx-service | head -5
```
**확인할 것**: 정상적으로 nginx 환영 페이지가 나오는지 — 이건 **같은 Namespace(`default`) 안의 서비스**로 연결된 겁니다. (dev의 nginx-service가 아닙니다!)

이번엔 짧은 이름 대신 전체 DNS 이름으로 `dev`의 서비스에 접근해보세요:
```bash
kubectl exec -it <default Pod 이름> -- curl -s http://nginx-service.dev.svc.cluster.local | head -5
```
**확인할 것**: 이것도 정상적으로 nginx 페이지가 나오는지 — 이번엔 진짜 `dev` Namespace의 서비스로 연결된 겁니다.

> 핵심 정리: 짧은 이름(`nginx-service`)은 **항상 자기 자신이 속한 Namespace 안에서** 찾습니다. 다른 Namespace의 리소스에 접근하려면 `<이름>.<네임스페이스>.svc.cluster.local` 형식이 필요합니다. 이름이 같아도 절대 서로 헷갈리거나 충돌하지 않는다는 걸 직접 확인한 것입니다.

## Step 6. 정리

Namespace를 통째로 지우면, 그 안의 리소스가 전부 함께 삭제됩니다. `dev` 쪽은 이렇게 한 번에 정리해보세요.

```bash
kubectl delete namespace dev
kubectl get pods -n dev
```
**확인할 것**: Namespace를 지운 것만으로 Deployment/Service/ConfigMap/Secret이 전부 같이 사라졌는지 (`kubectl get pods -n dev`가 에러 또는 빈 결과를 보여야 함).

`default` 쪽은 지금까지처럼 개별적으로 정리:
```bash
kubectl delete -f manifests/01-nginx-deployment.yaml
kubectl delete -f manifests/02-nginx-service.yaml
kubectl delete -f manifests/03-nginx-configmap.yaml
kubectl delete -f manifests/04-nginx-secret.yaml
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -n dev` — Pod가 `CreateContainerConfigError`면 ConfigMap/Secret이 그 Namespace에 없는 것. `-n dev`를 빼먹고 apply했는지 확인
2. `kubectl get all -n dev` — 리소스가 의도한 Namespace에 제대로 들어갔는지 확인
3. `curl`이 안 되면 `kubectl get endpoints nginx-service -n dev`로 Service 뒤에 연결된 Pod가 있는지 확인
4. 현재 어느 Namespace에서 작업 중인지 헷갈리면 `kubectl config view --minify | grep namespace`

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
