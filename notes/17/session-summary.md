# 2026-09-10 세션 요약 (17회차)

이 회차는 두 세션에 걸쳐 진행됨 — 개념/설계/가이드 작성 세션(커밋 0cfca06)과, 이 문서를 남긴 실습 세션.
(이전 세션 요약: [notes/16/session-summary.md](../16/session-summary.md))

## 이번 회차 목표

Multipass VM 2대로 kubeadm 멀티노드 클러스터를 직접 구성하는 큰 작업의 **1단계** — VM 준비 + 각 노드에 컨테이너 런타임(containerd)과 쿠버네티스 도구(kubeadm/kubelet/kubectl) 설치. 클러스터 자체는 아직 안 만듦.

## 한 일 순서

1. **이전 세션에서 막혔던 지점 복구** — `multipass launch`가 macOS vmnet 권한 문제로 실패했었는데, Mac 재부팅 후 VM 2대 정상 생성됨(사용자가 이전 세션 이후 직접 처리). 이번 세션 시작 시 `k8s-control`이 Stopped여서 Claude가 `multipass start k8s-control`로 기동.
2. **실습 진행** — `notes/17/practice-guide.md`의 Step 2~6을 사용자가 직접 실행. 완주 상세는 [practice-selfdone.md](practice-selfdone.md).
   - Step 2: `multipass shell`로 VM 접속해 평범한 Ubuntu 22.04 서버임을 확인
   - Step 3: `multipass transfer`로 `infra/prepare-node.sh`를 두 VM에 복사
   - Step 4~5: `multipass exec <VM> -- sudo bash prepare-node.sh`를 control→worker 순서로 실행, 5단계(swap/커널모듈/sysctl/containerd/k8s도구) 전부 통과
   - Step 6: 두 노드 모두 kubeadm **v1.31.14**, `containerd active`, `SystemdCgroup = true` 확인
3. **완주 기록 + 세션 요약 작성** (이 문서들).

## 배운 개념

새 개념 설명은 이전 세션(개념/설계 세션)에 이미 진행됨 — 클러스터 아키텍처, kubeadm, CNI 등은 `notes/concepts.md`에 정리되어 있음. 이번 실습 세션은 그 계획을 실제로 실행한 것.

핵심 감각: "클러스터를 만든다"는 것의 1단계는 **평범한 리눅스 서버를 쿠버네티스가 요구하는 상태로 맞추는 일**(swap off, 커널 네트워킹, 컨테이너 런타임, cgroup 드라이버 일치)이라는 것. Docker Desktop이 그동안 이걸 전부 숨겨주고 있었음.

## 현재 상태 (2026-09-10 기준)

- **새 클러스터용**: Multipass VM 2대 Running, 사전 요구사항 + 쿠버네티스 도구(v1.31.14) 설치 완료. 아직 `kubeadm init` 안 함 — 클러스터 미존재. 다음 세션까지 `multipass stop`으로 꺼둬도 됨.
- **기존 Docker Desktop 클러스터**: `webapp`/`monitoring`/`argocd` 세 Namespace 그대로 유지, 이번 회차에서 전혀 안 건드림.
- **GitHub 레포**: 17회차 실습 기록(practice-selfdone.md, session-summary.md) 커밋 예정.

## 다음 회차 (18) — Control Plane 구축

- `k8s-control`에서 `kubeadm init` 실행 (pod-network-cidr는 다음 회차 CNI(Calico)에 맞춰 지정)
- `~/.kube/config` 설정, `kubectl get nodes`로 control-plane 노드 확인 (CNI 없어서 `NotReady` 상태일 것)
- control-plane 구성요소 Pod(`kube-apiserver`, `etcd`, `kube-scheduler`, `kube-controller-manager`, `kube-proxy`) 확인
- 새 클러스터용 kubeconfig 컨텍스트가 생기므로 `kubectl config get-contexts`로 Docker Desktop 컨텍스트와 헷갈리지 않게 관리
- 가이드는 다음 세션에 `notes/18/practice-guide.md`로 작성
