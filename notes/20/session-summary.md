# 2026-09-15 세션 요약 (20회차)

다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/19/session-summary.md](../19/session-summary.md))

## 이번 회차 목표

kubeadm 멀티노드 클러스터 구성의 **4단계** — `k8s-worker`가 `kubeadm join`으로 클러스터에 합류해서 진짜 2노드 클러스터를 완성.

## 한 일 순서

1. **개념 설명 + 가이드 작성** — `kubeadm join`의 TLS Bootstrap(토큰+CA 해시로 워커↔컨트롤 플레인 상호 신뢰 수립), join 내부 단계(preflight→discovery→kubelet bootstrap→register), DaemonSet(kube-proxy/calico-node) 자동 확장 원리를 `notes/concepts.md`에 정리. `notes/20/practice-guide.md` 작성, README 갱신 후 커밋(0592186).
2. **실습 진행** — 상세는 [practice-selfdone.md](practice-selfdone.md). 요약:
   - 준비: 워커/컨트롤 둘 다 `conntrack`/`socat` 있음을 확인(우려했던 누락 없었음), 컨트롤 플레인은 19회차 마지막 상태 그대로임을 확인.
   - `sudo kubeadm token create --print-join-command`로 새 토큰 발급(CA 해시는 18회차와 동일).
   - **실수 발생**: join 명령을 `k8s-control` 터미널에서 실행(잘못된 노드) → preflight 에러 3건으로 실패, 하지만 아무 변경 전에 막혀서 안전. `k8s-worker` 터미널로 전환 후 재실행 → 성공.
   - 검증: 2노드 모두 `Ready`, `kube-proxy`/`calico-node`가 워커용으로 자동 하나씩 더 생긴 것까지 확인.
3. **완주 기록 + 세션 요약 작성** (이 문서들).

## 배운 개념: `kubeadm join`

`notes/concepts.md` 참고. 요약: 토큰(워커→클러스터 인증)과 CA 해시(클러스터→워커 검증)로 TLS Bootstrap을 안전하게 수행. 워커에는 컨트롤 플레인 컴포넌트가 전혀 안 뜨고, kubelet 등록 후 DaemonSet(kube-proxy, calico-node)이 새 Node를 감지해 **자동으로** 확장됨 — CNI를 워커에 별도 설치할 필요 없음.

## 현재 상태 (2026-09-15 기준)

- **새 kubeadm 클러스터**: `k8s-control`(control-plane) + `k8s-worker` **2노드 완성**, 전부 `Ready`/`Running`. 컨트롤 플레인은 control에만, kube-proxy/calico-node는 두 노드 모두에 존재.
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림.

## 다음 회차 (21) — 검증 (마지막 단계)

- 지금까지 배운 Deployment+Service를 이 새 클러스터에 재배포
- 여러 replica로 띄워서 `kubectl get pods -o wide`로 Pod가 `k8s-control`과 `k8s-worker` 양쪽에 실제로 분산 스케줄되는지 확인
- 필요하면 Service를 통해 실제 접속까지 확인 (노드 간 Pod 통신이 잘 되는지 최종 검증)
- 성공하면 `notes/17/design.md`에서 계획한 클러스터 직접 구성 프로젝트(17~21회차) 완주
