# 실습 13 가이드 — RBAC (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

지금까지 우리가 쓴 `kubectl` 명령어는 전부 관리자 권한(Docker Desktop 계정, `cluster-admin`)으로 실행됐습니다. 이번엔 **일부러 권한을 제한한 계정**을 하나 만들어서, 그 계정으로는 조회는 되는데 삭제는 막히는 걸 직접 확인해봅니다.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl get serviceaccount -n webapp
```
`default`라는 ServiceAccount가 이미 있을 겁니다 — Namespace를 만들면 자동으로 하나씩 생기는 기본 계정입니다. 지금까지 우리 Pod들은 전부 이걸 암묵적으로 써왔습니다.

## Step 1. 제한된 권한을 가질 ServiceAccount 만들기

```bash
nano manifests/project/15-readonly-sa.yaml
```
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: readonly-sa
  namespace: webapp
```
```bash
kubectl apply -f manifests/project/15-readonly-sa.yaml
kubectl get serviceaccount -n webapp
```

## Step 2. Role 만들기 — "Pod 조회만 가능"

```bash
nano manifests/project/16-pod-reader-role.yaml
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: webapp
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```
```bash
kubectl apply -f manifests/project/16-pod-reader-role.yaml
```

## Step 3. RoleBinding으로 ServiceAccount에 Role 연결

Role만 만들어서는 아직 아무 효과가 없습니다 — 이걸 `readonly-sa`에게 실제로 부여해야 합니다.

```bash
nano manifests/project/17-pod-reader-rolebinding.yaml
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: webapp
subjects:
  - kind: ServiceAccount
    name: readonly-sa
    namespace: webapp
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```
```bash
kubectl apply -f manifests/project/17-pod-reader-rolebinding.yaml
```

## Step 4. 빠르게 권한 확인하기 (`kubectl auth can-i`)

실제 Pod를 안 띄우고도, `--as` 옵션으로 "이 계정이었다면 이 동작이 가능했을까?"를 바로 물어볼 수 있습니다.

```bash
kubectl auth can-i list pods -n webapp --as=system:serviceaccount:webapp:readonly-sa
kubectl auth can-i delete pods -n webapp --as=system:serviceaccount:webapp:readonly-sa
```

**확인할 것**: 첫 번째는 `yes`, 두 번째는 `no`가 나오는지. Role에 `verbs: ["get", "list", "watch"]`만 넣었으니 조회는 되고 삭제는 막혀야 정상입니다.

비교삼아, 아무 권한도 안 준 `default` ServiceAccount는 어떨지도 확인해보세요:
```bash
kubectl auth can-i list pods -n webapp --as=system:serviceaccount:webapp:default
```
**확인할 것**: 이것도 `no`가 나오는지 — `default`는 우리가 아무 Role도 안 줬으니 아무 권한이 없는 게 정상입니다 (지금까지 우리 Pod들이 `default`를 써왔지만, K8s API를 직접 호출한 적이 없어서 문제가 안 됐던 것뿐입니다).

## Step 5. 진짜 Pod를 띄워서 실제로 API 호출해보기 (핵심)

`kubectl auth can-i`는 "물어보는 것"이었다면, 이번엔 진짜 `readonly-sa`를 쓰는 Pod를 하나 띄워서 그 안에서 직접 쿠버네티스 API를 호출해봅니다. 이게 실제로 앱이 클러스터와 통신하는 방식입니다.

```bash
nano manifests/project/18-rbac-test-pod.yaml
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rbac-test-pod
  namespace: webapp
spec:
  serviceAccountName: readonly-sa
  containers:
    - name: curl
      image: curlimages/curl:latest
      command: ["sleep", "3600"]
```
```bash
kubectl apply -f manifests/project/18-rbac-test-pod.yaml
kubectl get pod rbac-test-pod -n webapp
```
`Running`이 될 때까지 기다리세요.

## Step 6. 이 Pod 안에서 "조회"는 되는지 확인

모든 Pod에는 자기 ServiceAccount의 토큰(신분증)이 파일로 자동 마운트되어 있습니다. 그 토큰으로 쿠버네티스 API 서버에 직접 요청을 보내봅니다.

```bash
kubectl exec -n webapp rbac-test-pod -- sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/webapp/pods
'
```
**확인할 것**: `HTTP 200`이 나오는지. `pods` 목록을 조회하는 API를 성공적으로 호출한 것입니다.

## Step 7. 같은 Pod 안에서 "삭제" 시도 → 거부되는지 확인 (핵심)

이번엔 실제로 Pod 하나를 지워보는 요청을 보냅니다 (`postgres-0`을 대상으로 — 실제로 지워지면 안 되니 결과를 잘 확인하세요).

```bash
kubectl exec -n webapp rbac-test-pod -- sh -c '
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -s \
  --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  -X DELETE \
  https://kubernetes.default.svc/api/v1/namespaces/webapp/pods/postgres-0
'
```

**확인할 것**: 응답이 성공(200)이 아니라 **`403 Forbidden`**이고, 메시지에 `cannot delete resource "pods"` 같은 문구가 담겨있는지.

```bash
kubectl get pod postgres-0 -n webapp
```
`postgres-0`이 여전히 멀쩡하게 살아있는지도 확인하세요 — 삭제 요청이 실제로 거부돼서 아무 일도 안 일어났어야 합니다.

## Step 8. (참고) 여러분의 진짜 kubectl은 왜 다 됐었나

지금까지 실습 1~12회차에서 쓴 `kubectl`은 Docker Desktop이 자동으로 만들어준 관리자 계정(`cluster-admin` 권한)을 쓰고 있어서 뭐든 다 됐던 겁니다. 확인해보세요:

```bash
kubectl auth can-i delete pods -n webapp
kubectl auth can-i delete namespaces
```
둘 다 `yes`가 나올 겁니다 (`--as` 옵션 없이 물으면 지금 로그인된 나 자신의 권한을 확인하는 것). 이게 여태까지 아무 제약 없이 실습할 수 있었던 이유입니다.

## Step 9. 정리

```bash
kubectl delete -f manifests/project/18-rbac-test-pod.yaml
kubectl delete -f manifests/project/17-pod-reader-rolebinding.yaml
kubectl delete -f manifests/project/16-pod-reader-role.yaml
kubectl delete -f manifests/project/15-readonly-sa.yaml
```

## 막혔을 때 자가진단 순서
1. Step 4의 `kubectl auth can-i`가 예상과 다르게 나오면 `kubectl get rolebinding,role -n webapp`로 이름/네임스페이스가 정확한지 확인
2. Step 6에서 `HTTP 000`이나 연결 실패가 나오면 `kubectl get pod rbac-test-pod -n webapp`로 Pod가 진짜 `Running`인지 확인
3. Step 7에서 403이 아니라 200이 나오면(=삭제가 실제로 성공해버림) RoleBinding의 `subjects`/`roleRef` 이름 오타 의심 — `kubectl describe rolebinding read-pods-binding -n webapp`로 재확인
4. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
