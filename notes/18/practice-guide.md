# 실습 18 가이드 — 2단계: Control Plane 구축 (`kubeadm init`)

전체 계획: [../17/design.md](../17/design.md) · 개념: [../concepts.md](../concepts.md) "kubeadm init이 실제로 하는 일"

이 가이드를 보면서 터미널에 직접 입력해보세요. 막히면 명령어 결과를 그대로 붙여넣어 주시면 같이 확인합니다.

이번 회차 목표: `k8s-control` VM에서 `kubeadm init`을 실행해 **컨트롤 플레인을 실제로 부팅**하고, `kubectl`로 클러스터에 접속되는 것까지 확인합니다. CNI가 없어서 노드는 `NotReady`로 뜨는데, 그건 정상이고 다음 회차(19)에서 해결합니다. 워커 합류도 다음(20)입니다.

## 준비 — VM 기동 및 상태 확인

Mac 터미널에서:
```bash
multipass list
```
`k8s-control`, `k8s-worker` 둘 다 `Running`인지 확인. 꺼져 있으면:
```bash
multipass start k8s-control k8s-worker
```

`k8s-control`의 IP를 확인해 둡니다 (아래 `kubeadm init`에 사용):
```bash
multipass exec k8s-control -- ip -4 addr show enp0s1 | grep inet
```
17회차 기준 `192.168.252.6` 였습니다. **바뀌었으면 아래 명령의 IP를 실제 값으로 바꿔서** 진행하세요.

## Step 1. control 노드 안으로 들어가기

이번 실습은 전부 `k8s-control` VM **안에서** 진행합니다.
```bash
multipass shell k8s-control
```
이후 프롬프트가 `ubuntu@k8s-control:~$` 로 바뀝니다.

## Step 2. (실행 전) preflight 미리 점검 — 선택

`kubeadm init`은 시작할 때 스스로 환경을 점검하지만, 미리 한 번 돌려볼 수 있습니다:
```bash
sudo kubeadm init phase preflight \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.252.6
```
에러 없이 끝나거나 `[preflight] ... looks good` 계열 메시지면 통과입니다. `[WARNING ...]` 는 대부분 무시 가능(특히 `Service-Kubelet` 관련). `[ERROR ...]` 가 나오면 붙여넣어 주세요.

## Step 3. `kubeadm init` 실행

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.252.6
```

- `--pod-network-cidr=10.244.0.0/16` — Pod에 나눠줄 IP 대역. **19회차 Calico 설정과 반드시 같은 값을 써야 합니다.** (노드 IP가 `192.168.252.x`라서 Calico 기본값 `192.168.0.0/16`은 피합니다.)
- `--apiserver-advertise-address` — apiserver가 광고할 주소. `k8s-control`의 `enp0s1` IP.

2~4분 정도 걸립니다. 컨테이너 이미지를 받아오고, 인증서를 만들고, 컨트롤 플레인 static Pod가 뜨고, apiserver가 healthy 해질 때까지 기다립니다.

**성공 시 출력 마지막**에 이런 블록이 나옵니다:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ...
Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.252.6:6443 --token <....> \
        --discovery-token-ca-cert-hash sha256:<....>
```

### ⚠️ 맨 아래 `kubeadm join ...` 두 줄을 통째로 복사해서 어딘가에 저장하세요.
20회차에서 `k8s-worker`를 합류시킬 때 씁니다. 잃어버려도 나중에 재발급 가능하니 너무 걱정은 마세요:
```bash
kubeadm token create --print-join-command
```

## Step 4. kubeconfig 설정

`kubeadm init`이 알려준 그대로, `k8s-control` 안에서:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
이제 이 VM 안에서 `kubectl`이 새 클러스터를 가리킵니다. (Mac의 `kubectl`은 계속 Docker Desktop을 봅니다 — 안 건드립니다.)

## Step 5. 검증

```bash
kubectl get nodes
```
**예상 결과**: `k8s-control` 한 대, `STATUS`는 `NotReady`, `ROLES`는 `control-plane`.
→ `NotReady`는 **정상**입니다. CNI(네트워크 플러그인)가 아직 없어서 그렇습니다.

```bash
kubectl get pods -n kube-system
```
**예상 결과**:
- `etcd-k8s-control`, `kube-apiserver-k8s-control`, `kube-controller-manager-k8s-control`, `kube-scheduler-k8s-control`, `kube-proxy-xxxxx` → `Running`
- `coredns-xxxx` 2개 → **`Pending`** (CNI 없어서 스케줄 안 됨 — 정상)

```bash
kubectl get pods -n kube-system -o wide
kubectl -n kube-system describe pod -l k8s-app=kube-dns | tail -20
```
CoreDNS가 `Pending`인 이유가 `node(s) had untolerated taint ... not-ready` / `network plugin is not ready` 로 나오면 예상대로입니다.

컨트롤 플레인 static Pod의 실제 정의 위치도 눈으로 확인해보세요:
```bash
ls /etc/kubernetes/manifests/
```
`etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml` 4개가 보입니다.

## Step 6. (선택) 클러스터 정보 확인

```bash
kubectl cluster-info
kubectl get --raw='/healthz?verbose'
kubectl version
```
`kubectl get --raw='/healthz?verbose'` 가 전부 `ok` 면 apiserver/etcd/컨트롤러가 건강합니다.

## 여기서 멈추는 이유

컨트롤 플레인은 떴지만, **Pod 네트워킹이 없어서** 노드가 `NotReady`이고 CoreDNS도 못 뜹니다. 이 상태에서 워커를 합류시키면 워커도 똑같이 `NotReady`가 됩니다. 그래서 다음 순서는:
- **19회차**: CNI(Calico) 설치 → `k8s-control` 이 `Ready`로, CoreDNS가 `Running`으로 바뀌는 것 확인
- **20회차**: `k8s-worker` 에서 `kubeadm join` → 2노드 클러스터 완성

## 막혔을 때 자가진단

1. **`kubeadm init`이 preflight에서 `[ERROR ...]`로 멈춤**
   - `Swap`: `sudo swapoff -a` 다시 실행 후 재시도 (17회차 스크립트가 껐지만 재부팅으로 살아났을 수 있음)
   - `CRI` / `container runtime is not running`: `sudo systemctl status containerd` 확인, `sudo systemctl restart containerd`
   - `Port 6443 / 10259 / 10257 / 2379 ... in use`: 이미 `kubeadm init`을 한 번 돌린 상태 → **아래 "처음부터 다시" 참고**
2. **`kubeadm init`이 `timed out waiting for the condition` / `a running instance of kubelet` 관련으로 멈춤**
   - `sudo journalctl -u kubelet -n 50 --no-pager` 로 kubelet 로그 확인
   - cgroup 드라이버 불일치면 여기서 터짐 — 17회차에서 `SystemdCgroup = true` 확인했으니 가능성 낮음
   - `sudo crictl ps -a` 로 컨트롤 플레인 컨테이너가 뜨는지/죽는지 확인 (`crictl`은 이미 설치돼 있음)
3. **`sandbox_image` / `pause` 이미지 관련 경고나 에러**
   - `sudo kubeadm config images list` 로 kubeadm이 원하는 pause 버전 확인
   - `grep sandbox_image /etc/containerd/config.toml` 와 비교, 다르면 그 줄을 kubeadm 값으로 바꾸고 `sudo systemctl restart containerd` 후 재시도
4. **이미지 pull 실패 (`registry.k8s.io` 접속 안 됨)**
   - `multipass exec k8s-control -- ping -c3 registry.k8s.io` 로 네트워크 확인
   - 되면 그냥 재시도 (일시적 실패일 수 있음)

### 처음부터 다시 (`kubeadm init`을 깨끗이 되돌리기)
`kubeadm init`이 중간에 실패했거나 잘못된 플래그로 돌렸을 때:
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube
# iptables 잔여물까지 지우려면 (선택):
# sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
```
그리고 Step 3부터 다시 진행합니다.

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요.
