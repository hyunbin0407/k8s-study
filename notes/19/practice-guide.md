# 실습 19 가이드 — 3단계: CNI 설치 (Calico)

전체 계획: [../17/design.md](../17/design.md) · 개념: [../concepts.md](../concepts.md) "Calico 설치가 실제로 하는 일"

이번 회차 목표: `k8s-control`에 Calico를 설치해서, 18회차에서 `NotReady`였던 노드가 **`Ready`**로, `Pending`이던 CoreDNS가 **`Running`**으로 바뀌는 것을 확인합니다.

## 준비

```bash
multipass list   # k8s-control, k8s-worker 둘 다 Running인지 확인
multipass shell k8s-control
```
이후 전부 `k8s-control` 안에서 진행합니다. (18회차 그대로면 `kubectl`이 이미 새 클러스터를 가리킵니다.)

```bash
kubectl get nodes
kubectl get pods -n kube-system
```
18회차 마지막 상태(`k8s-control NotReady`, `coredns Pending` 2개) 그대로인지 먼저 확인하세요.

## Step 1. Calico 매니페스트 다운로드

```bash
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml
```
큰 파일(수천 줄)입니다 — CRD, RBAC, DaemonSet, Deployment가 전부 이 한 파일 안에 있습니다.

> 만약 404가 뜨면 Calico 버전 태그가 바뀐 것일 수 있습니다. `v3.29.1` 대신 `v3.29.0` 등을 시도하거나, 알려주시면 최신 태그를 같이 확인하겠습니다.

## Step 2. Pod CIDR을 우리 값에 맞게 수정

기본값(`192.168.0.0/16`)을 18회차의 `--pod-network-cidr=10.244.0.0/16`에 맞춰야 합니다. 파일 안에 이미 그 설정이 **주석 처리되어** 있습니다.

```bash
nano calico.yaml
```
`Ctrl+W`로 `CALICO_IPV4POOL_CIDR`를 검색하면 이런 두 줄이 나옵니다:
```yaml
            # - name: CALICO_IPV4POOL_CIDR
            #   value: "192.168.0.0/16"
```
**정확히 맨 앞의 `# ` (샵+스페이스) 두 글자만** 지우고, 값을 바꿔서 아래처럼 만드세요 (다른 공백/들여쓰기는 건드리지 마세요):
```yaml
            - name: CALICO_IPV4POOL_CIDR
              value: "10.244.0.0/16"
```
저장하고 나갑니다 (`Ctrl+O`, `Enter`, `Ctrl+X`).

**확인**:
```bash
grep -A1 CALICO_IPV4POOL_CIDR calico.yaml
```
주석(`#`) 없이 두 줄이 보이고 값이 `10.244.0.0/16`이면 성공입니다.

## Step 3. 적용

```bash
kubectl apply -f calico.yaml
```
CRD 수십 개, ServiceAccount, ClusterRole, DaemonSet, Deployment 등 수십 개 리소스가 한 번에 생성됩니다.

## Step 4. 뜨는 것 지켜보기

이미지를 받아오느라 1~2분 걸릴 수 있습니다.
```bash
watch kubectl get pods -n kube-system
```
(`Ctrl+C`로 종료) `calico-node-xxxxx`와 `calico-kube-controllers-xxxxx`가 `Pending`/`ContainerCreating`을 거쳐 `Running`이 되는 것, 그리고 그동안 `Pending`이던 `coredns-xxxxx` 2개도 함께 `Running`으로 바뀌는 것을 지켜보세요.

## Step 5. 검증

```bash
kubectl get nodes
```
**예상 결과**: `k8s-control`의 `STATUS`가 이제 **`Ready`**.

```bash
kubectl get pods -n kube-system
```
**예상 결과**: 전부 `Running` — `calico-node`, `calico-kube-controllers`, `coredns` 2개 포함 컨트롤 플레인/kube-proxy까지 전부.

```bash
kubectl get pods -n kube-system -o wide
```
`calico-node`는 호스트 네트워크라 `NODE`의 IP(`192.168.252.6`)를 그대로 쓰고, `calico-kube-controllers`와 `coredns`는 **새 Pod 네트워크 대역**(`10.244.x.x`)의 IP를 받은 걸 확인해보세요 — Calico가 실제로 동작한다는 증거입니다.

(선택) Calico가 만든 IPPool 리소스도 들여다볼 수 있습니다:
```bash
kubectl get ippools.crd.projectcalico.org -o wide
```

## 여기서 멈추는 이유

컨트롤 플레인 노드 하나짜리 클러스터가 완전히 `Ready` 상태가 됐습니다. 하지만 아직 워커 노드가 클러스터에 없습니다. 다음 회차(20)에서 `k8s-worker`가 `kubeadm join`으로 합류하면 진짜 멀티노드 클러스터가 완성됩니다.

## 막혔을 때 자가진단

1. **`calico-node`가 `CrashLoopBackOff` / `Error`**
   - `kubectl logs -n kube-system <calico-node-파드이름>` 확인
   - VM 네트워크 인터페이스가 여러 개라 Calico가 잘못된 인터페이스를 잡은 경우일 수 있음 — 로그에 `no valid IP address found` 등이 보이면 알려주세요 (인터페이스 자동감지 설정을 조정해야 할 수 있음)
2. **`ImagePullBackOff`**
   - `kubectl describe pod -n kube-system <파드이름>` 로 어떤 이미지가 실패했는지 확인
   - Docker Hub(`docker.io/calico/...`) 레이트 리밋으로 일시 실패했을 수 있음 — 몇 분 후 자동 재시도됨
3. **CIDR을 안 바꾸고 그냥 apply해버린 경우**
   - 노드가 `Ready`는 되는데 Pod가 IP를 못 받거나 이상한 대역을 받을 수 있음
   - `kubectl delete -f calico.yaml` 후 Step 2부터 다시 (CRD 삭제까지 시간이 좀 걸릴 수 있음)
4. **노드가 여전히 `NotReady`**
   - `kubectl describe node k8s-control | grep -A5 Conditions` 로 `Ready` 조건의 메시지 확인
   - `sudo journalctl -u kubelet -n 50 --no-pager` 로 kubelet 쪽 에러 확인

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요.
