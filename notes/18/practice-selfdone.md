# 실습 18 — 직접 완주! Control Plane 구축 (`kubeadm init`)

가이드: [practice-guide.md](practice-guide.md) · 개념: [../concepts.md](../concepts.md) "kubeadm init이 실제로 하는 일"

## 진행 내용

1. **준비** — `k8s-control` IP가 17회차와 동일한 `192.168.252.6`임을 확인, `multipass shell k8s-control`로 접속. 이후 전 과정을 VM 안에서 진행.
2. **preflight에서 막힌 것 2건 (해결)**:
   - `kubeadm init phase preflight`에 `--pod-network-cidr` 플래그를 넣으면 `unknown flag` — `phase preflight` 하위 명령은 그 플래그를 안 받음. 플래그 없이 `sudo kubeadm init phase preflight`로 실행.
   - `[ERROR FileExisting-conntrack]: conntrack not found in system path` — 17회차 `prepare-node.sh`에 `conntrack`이 누락됨. `sudo apt-get install -y conntrack socat`로 설치 후 통과. (`infra/prepare-node.sh`도 이번에 수정해 커밋.)
3. **`kubeadm init` 실행**:
   ```bash
   sudo kubeadm init \
     --pod-network-cidr=10.244.0.0/16 \
     --apiserver-advertise-address=192.168.252.6
   ```
   - `W... sandbox image "" ... inconsistent ... recommended "registry.k8s.io/pause:3.10"` 경고가 떴지만 **무시** — containerd 2.2.1은 내장 pause 기본값이 이미 3.10이라 kubeadm 1.31이 원하는 값과 동일. init은 정상 진행됨.
   - 진행 로그에서 개념과 1:1로 대응하는 단계들을 눈으로 확인: `[certs]`(CA + 구성요소 인증서), `[kubeconfig]`(admin.conf 등), `[etcd]`/`[control-plane]`(static Pod manifest 작성), `[kubelet-start]`, `[api-check] The API server is healthy after 4.5s`, `[bootstrap-token]`, `[addons] CoreDNS / kube-proxy`.
   - `kubeadm token create --print-join-command`를 sudo 없이 쳐서 `permission denied` — join 명령은 init 출력에 이미 있으므로 무시.
4. **kubeconfig 설정** — init이 안내한 그대로 `mkdir -p $HOME/.kube` → `sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config` → `sudo chown`.
5. **검증** (전부 예상대로):
   - `kubectl get nodes` → `k8s-control` 1대, `STATUS: NotReady`, `ROLES: control-plane`, `v1.31.14`
   - `kubectl get pods -n kube-system` → `etcd` / `kube-apiserver` / `kube-controller-manager` / `kube-scheduler` / `kube-proxy` = `Running`, **`coredns` 2개 = `Pending`**
   - CoreDNS `describe` → `FailedScheduling: 0/1 nodes are available: 1 node(s) had untolerated taint {node.kubernetes.io/not-ready}` — 노드가 NotReady라 스케줄 자체가 안 됨
   - `ls /etc/kubernetes/manifests/` → `etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`

## join 명령 (20회차에서 사용)

```
kubeadm join 192.168.252.6:6443 --token wwx8p5.sxod5ayse4ec7pp0 \
    --discovery-token-ca-cert-hash sha256:639ec3af5a4144e15e12f961c53ac3d72fc42145b6e79cb2f7e2a4013a563e5a
```
**부트스트랩 토큰은 24시간 후 만료.** 20회차를 다음 날 이후에 하면 `k8s-control`에서 `sudo kubeadm token create --print-join-command`로 새로 발급하면 됨 (CA 해시는 그대로).

## 배운 것 요약

- `kubeadm init` 로그는 개념 표(preflight → certs → kubeconfig → control-plane static Pod → kubelet → token → addon)와 그대로 일치 — "한 줄 명령"이 실제로 뭘 하는지 눈으로 확인함.
- 컨트롤 플레인 4개(etcd/apiserver/controller-manager/scheduler)는 `/etc/kubernetes/manifests/`의 YAML로 정의된 **static Pod**. kube-proxy는 DaemonSet.
- **CNI가 없으면**: kubelet이 노드에 `node.kubernetes.io/not-ready` taint를 유지 → 노드 `NotReady` → 그 taint를 못 견디는 Pod(CoreDNS)는 `Pending`. 컨트롤 플레인/kube-proxy는 host network라 영향 없음.
- `--pod-network-cidr=10.244.0.0/16`는 19회차 Calico 설정과 **반드시 일치**시켜야 함. (노드 IP가 `192.168.252.x`라 Calico 기본값 `192.168.0.0/16`은 피함.)

## 현재 상태 (2026-09-11 기준)

- **새 kubeadm 클러스터**: `k8s-control` 1노드, 컨트롤 플레인 `Running`, 노드 `NotReady`(CNI 대기). kubeconfig는 `k8s-control` VM 안 `~/.kube/config`에만 존재 — Mac의 `kubectl`은 계속 Docker Desktop.
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림.
- 다음: 19회차 CNI(Calico) 설치 → 20회차 `k8s-worker` join.
