# 2026-09-11 세션 요약 (18회차)

다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/17/session-summary.md](../17/session-summary.md))

## 이번 회차 목표

kubeadm 멀티노드 클러스터 구성의 **2단계** — `k8s-control` VM에서 `kubeadm init`을 실행해 컨트롤 플레인을 실제로 부팅하고, `kubectl`로 접속되는 것까지 확인. CNI/워커 합류는 다음 회차.

## 한 일 순서

1. **개념 설명** — `kubeadm init`이 내부적으로 하는 일(preflight → CA/인증서 → kubeconfig → 컨트롤 플레인 static Pod → kubelet 기동 → bootstrap token → 애드온), static Pod로 부트스트랩 모순을 푸는 법, `--pod-network-cidr` / `--apiserver-advertise-address` 플래그, init 직후 `NotReady` + CoreDNS `Pending`이 정상인 이유. `notes/concepts.md`에 "kubeadm init이 실제로 하는 일 (18회차)" 섹션으로 정리.
2. **실습 가이드 작성** — `notes/18/practice-guide.md`. README 표에 18회차 행 추가. 개념+가이드 먼저 커밋(277d8de).
3. **실습 진행** — 상세는 [practice-selfdone.md](practice-selfdone.md). 요약:
   - preflight 2건 막힘 → 해결: (a) `phase preflight`에 `--pod-network-cidr` 못 넣음(가이드 수정함), (b) `conntrack` 패키지 누락 → `apt-get install -y conntrack socat`, `infra/prepare-node.sh`도 수정.
   - `sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.252.6` 성공. sandbox image `""` 경고는 무시(containerd 2.2.1 내장 기본값이 이미 pause:3.10).
   - kubeconfig 복사 후 검증: 노드 `NotReady`(정상), 컨트롤 플레인 5개 `Running`, CoreDNS 2개 `Pending`(taint `node.kubernetes.io/not-ready` 때문), `/etc/kubernetes/manifests/`에 static Pod YAML 4개.
4. **완주 기록 + 세션 요약 작성** (이 문서들).

## 배운 개념: kubeadm init

`notes/concepts.md` 참고. 요약: `kubeadm init` 한 줄이 preflight/인증서/kubeconfig/컨트롤 플레인 static Pod/kubelet/토큰/애드온을 순서대로 수행. 컨트롤 플레인 4대는 `/etc/kubernetes/manifests/`의 YAML로 정의된 static Pod(kubelet이 직접 실행, apiserver 불필요). CNI가 없으면 노드 `NotReady` + 네트워크 필요한 Pod는 `Pending` — 정상이며 CNI 설치로 풀림.

## 현재 상태 (2026-09-11 기준)

- **새 kubeadm 클러스터**: `k8s-control` 1노드. 컨트롤 플레인 Pod `Running`, 노드 `NotReady`(CNI 대기 중), CoreDNS `Pending`. kubeconfig는 `k8s-control` VM 안 `~/.kube/config`에만 존재. Mac `kubectl`은 계속 Docker Desktop을 가리킴.
- **VM**: `k8s-control`, `k8s-worker` 모두 Running. 다음 세션까지 `multipass stop k8s-control k8s-worker`로 꺼둬도 됨. (컨트롤 플레인 상태는 재기동 후에도 유지됨 — etcd가 디스크에 저장.)
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림.
- **join 명령**: `notes/18/practice-selfdone.md`에 저장. 토큰은 24h 만료 → 20회차에서 필요 시 `sudo kubeadm token create --print-join-command` 재발급.

## 다음 회차 (19) — CNI 설치 (Calico)

- `k8s-control`에서 Calico(Operator 방식 또는 manifest) 설치
- Calico의 IPPool CIDR을 **`10.244.0.0/16`** (18회차 `--pod-network-cidr`와 동일)로 맞추기 — 다르면 Pod 네트워킹 깨짐
- 설치 후 확인: `k8s-control` 노드가 `Ready`로, CoreDNS 2개가 `Running`으로 전환, `kube-system`에 `calico-node` / `calico-kube-controllers` Pod 등장
- 가이드는 다음 세션에 `notes/19/practice-guide.md`로 작성
- 이후 20(worker join, worker에 `conntrack`/`socat` 먼저 설치) → 21(검증)
