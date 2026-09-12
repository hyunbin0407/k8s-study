# 2026-09-12 세션 요약 (19회차)

이 회차는 두 세션에 걸쳐 진행됨 — 개념/가이드 작성 세션(커밋 a7346c7)과, 이 문서를 남긴 실습 세션.
(이전 세션 요약: [notes/18/session-summary.md](../18/session-summary.md))

## 이번 회차 목표

kubeadm 멀티노드 클러스터 구성의 **3단계** — `k8s-control`에 CNI(Calico)를 설치해서 18회차에서 `NotReady`였던 노드를 `Ready`로, `Pending`이던 CoreDNS를 `Running`으로 전환.

## 한 일 순서

1. **개념 설명 + 가이드 작성** (이전 세션) — Calico 구성요소(calico-node DaemonSet / calico-kube-controllers Deployment / CRD), Pod CIDR 블록 할당, IP-in-IP 라우팅, 설치 완료 신호(NotReady→Ready, CoreDNS Pending→Running)를 `notes/concepts.md`에 정리. `notes/19/practice-guide.md` 작성 후 커밋(a7346c7).
2. **실습 진행** — 상세는 [practice-selfdone.md](practice-selfdone.md). 요약:
   - 준비 확인: 18회차 마지막 상태 그대로임을 재확인.
   - `calico.yaml`(v3.29.1) 다운로드 → `CALICO_IPV4POOL_CIDR`를 `10.244.0.0/16`으로 수정(1차 시도에서 주석만 지우고 값은 안 바꿔서 재수정) → `kubectl apply`.
   - 1~2분 안에 `calico-node`/`calico-kube-controllers` `Running` 전환, CoreDNS 2개도 함께 `Running` 전환, 노드 `Ready` 전환 전부 확인. Pod IP가 `10.244.x.x` 대역인 것까지 `-o wide`로 검증.
3. **완주 기록 + 세션 요약 작성** (이 문서들).

## 배운 개념: Calico (CNI)

`notes/concepts.md` 참고. 요약: CNI가 없으면 컨트롤 플레인이 떠 있어도 Pod 간 네트워킹이 안 돼 노드가 `NotReady`. Calico는 DaemonSet(`calico-node`, 노드별 라우팅/iptables 에이전트) + Deployment(`calico-kube-controllers`, API 감시) + CRD(`IPPool` 등)로 구성. `CALICO_IPV4POOL_CIDR`는 `kubeadm init`의 `--pod-network-cidr`와 반드시 일치해야 함. 설치 완료 = kubelet이 "네트워크 준비됨"을 보고 → `not-ready` taint 해제 → 노드 `Ready` → CoreDNS 스케줄 가능.

## 현재 상태 (2026-09-12 기준)

- **새 kubeadm 클러스터**: `k8s-control` 1노드, 완전히 `Ready`. 컨트롤 플레인/kube-proxy/CoreDNS/calico-node/calico-kube-controllers 전부 `Running`. 아직 단일 노드(워커 미합류).
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림.

## 다음 회차 (20) — worker join

- `k8s-worker`에 `conntrack`/`socat`이 설치돼 있는지 먼저 확인(17회차 `prepare-node.sh`는 18회차에서 수정됨 — `k8s-worker`는 아직 옛 버전으로 설치됐을 수 있으니 확인 필요)
- 부트스트랩 토큰 24h 만료 여부 확인 — 지났으면 `k8s-control`에서 `sudo kubeadm token create --print-join-command` 재발급
- `k8s-worker`에서 `sudo kubeadm join ...` 실행
- `kubectl get nodes`로 2노드(`control-plane` + `worker`) 확인, `kube-proxy`/`calico-node`가 워커에도 뜨는지 확인
- 가이드는 다음 세션에 `notes/20/practice-guide.md`로 작성
- 이후 21(전체 검증 — Pod가 워커에 스케줄되는지, 노드 간 통신 등)
