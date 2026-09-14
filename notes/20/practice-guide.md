# 실습 20 가이드 — 4단계: Worker 합류 (`kubeadm join`)

전체 계획: [../17/design.md](../17/design.md) · 개념: [../concepts.md](../concepts.md) "`kubeadm join`이 실제로 하는 일"

이번 회차 목표: `k8s-worker`가 `kubeadm join`으로 클러스터에 합류해서, 진짜 2노드 클러스터를 완성합니다.

## 준비

```bash
multipass list
```
`k8s-control`, `k8s-worker` 둘 다 확인하고, `Stopped`면 기동합니다.
```bash
multipass start k8s-control k8s-worker
```

### 컨트롤 플레인 상태 확인

```bash
multipass shell k8s-control
kubectl get nodes
kubectl get pods -n kube-system
```
19회차 마지막 상태(`k8s-control Ready`, `kube-system` 전부 `Running`) 그대로인지 확인하세요.

### 워커에 conntrack/socat 있는지 확인 (중요)

`k8s-worker`는 17회차 때 구버전 `prepare-node.sh`(conntrack 누락 버전)로 설치됐을 가능성이 있습니다. join 전에 미리 확인합니다.

새 터미널 창에서:
```bash
multipass shell k8s-worker
which conntrack socat
```
두 명령 다 경로(`/usr/sbin/conntrack` 등)가 나오면 통과 — Step 2로 건너뛰세요.

**아무것도 안 나오면** (설치 안 된 경우):
```bash
sudo apt-get update
sudo apt-get install -y conntrack socat
which conntrack socat
```
이번엔 경로가 나와야 합니다.

## Step 1. join 명령 준비 (k8s-control에서)

18회차에서 저장해둔 join 명령의 토큰은 24시간짜리라 지금은 만료됐을 가능성이 높습니다. `k8s-control` 쪽 터미널에서 새로 발급받습니다:

```bash
sudo kubeadm token create --print-join-command
```
출력되는 한 줄(`kubeadm join 192.168.252.6:6443 --token ... --discovery-token-ca-cert-hash sha256:...`)을 **그대로 복사**해두세요. (CA 해시는 클러스터가 그대로라 18회차와 동일할 수 있지만, 토큰은 새 값입니다.)

## Step 2. join 실행 (k8s-worker에서)

`k8s-worker` 쪽 터미널로 돌아가서, 복사해둔 명령 앞에 `sudo`만 붙여 실행합니다:

```bash
sudo kubeadm join 192.168.252.6:6443 --token <복사한 토큰> \
    --discovery-token-ca-cert-hash sha256:<복사한 해시>
```

preflight 통과 후 `This node has joined the cluster.` 메시지가 나오면 성공입니다.

> 만약 preflight에서 에러가 나면(conntrack 관련 등) 위 "준비" 단계로 돌아가 패키지 설치를 다시 확인하세요.

## Step 3. 검증 (k8s-control에서)

```bash
kubectl get nodes
```
**예상 결과**: `k8s-control`(`ROLES: control-plane`)과 `k8s-worker`(`ROLES:` 빈 값) 2개. `k8s-worker`는 처음엔 `NotReady`였다가 몇 초~1분 안에 CNI Pod가 뜨면서 `Ready`로 바뀝니다.

```bash
watch kubectl get pods -n kube-system -o wide
```
(`Ctrl+C`로 종료) `kube-proxy-xxxxx`와 `calico-node-xxxxx`가 `k8s-worker`용으로 **새로 하나씩 더** 생기는 것을 지켜보세요 — DaemonSet이 새 Node를 감지해 자동 확장하는 걸 직접 보는 겁니다.

```bash
kubectl get nodes -o wide
```
두 노드의 `INTERNAL-IP`가 각각 `192.168.252.6`(control), `192.168.252.5`(worker)인지 확인.

## 여기서 멈추는 이유

2노드짜리 진짜 kubeadm 클러스터가 완성됐습니다. 다음 회차(21)에서 지금까지 배운 Deployment+Service를 이 클러스터에 재배포해서, Pod가 두 노드에 실제로 분산 스케줄되는 것까지 확인하며 전체 구축 과정을 마무리합니다.

## 막혔을 때 자가진단

1. **join이 preflight에서 실패** (`conntrack`/`socat` 관련)
   - "준비" 섹션의 패키지 설치를 다시 확인
2. **`error execution phase preflight: couldn't validate the identity of the API Server` 또는 토큰 관련 에러**
   - 토큰이 만료됐거나 잘못 복사됨 — `k8s-control`에서 `sudo kubeadm token create --print-join-command`로 재발급 후 다시 시도
3. **`k8s-worker`가 계속 `NotReady`**
   - `kubectl get pods -n kube-system -o wide`로 해당 노드에 `calico-node`가 떴는지 확인
   - 안 떴으면 `kubectl describe pod -n kube-system <calico-node-worker파드>`로 원인 확인 (이미지 pull 중일 수 있음 — 잠깐 기다려보기)
4. **`multipass shell`로 접속이 안 될 때**
   - `multipass list`로 VM이 `Running` 상태인지 먼저 확인

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요.
