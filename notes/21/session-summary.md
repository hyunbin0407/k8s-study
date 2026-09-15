# 2026-09-15 세션 요약 (21회차) — 클러스터 직접 구성 프로젝트 완주 🎉

다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/20/session-summary.md](../20/session-summary.md))

## 이번 회차 목표

kubeadm 클러스터 구성의 **5단계(마지막)** — 지금까지 배운 Deployment+Service를 새 2노드 클러스터에 재배포해서 Pod 분산 스케줄링과 노드 간 통신을 실제로 검증. 이걸로 17회차부터 시작한 "클러스터 직접 구성" 프로젝트를 마무리.

## 한 일 순서

1. **개념 설명 + 가이드 작성** — kubeadm이 기본으로 거는 control-plane taint(`node-role.kubernetes.io/control-plane:NoSchedule`), taint/toleration 메커니즘, 워커 1대뿐인 우리 랩에서 taint를 제거해야 노드 분산을 관찰할 수 있는 이유를 `notes/concepts.md`에 정리. `notes/21/practice-guide.md` 작성, README 갱신 후 커밋(7c71668).
2. **실습 진행** — 상세는 [practice-selfdone.md](practice-selfdone.md). 요약:
   - taint 확인 후 제거 (`kubectl taint nodes k8s-control ...:NoSchedule-`)
   - `cluster-verify` namespace에 `nginxdemos/hello` 6 replica Deployment + ClusterIP Service 배포
   - Pod가 `k8s-control`(2개, `10.244.175.x`)과 `k8s-worker`(4개, `10.244.254.x`) 양쪽에 분산된 것 확인
   - `busybox` 테스트 Pod로 Service에 8번 반복 요청 → 응답이 양쪽 노드 Pod를 오가며 옴 → Calico 노드 간 라우팅이 실전에서 동작함을 최종 확인
   - "정리도 너가 해줘" 요청으로 Claude가 `multipass exec`로 `cluster-verify` namespace 삭제 대행(taint는 복구 안 하고 유지)
3. **완주 기록 + 세션 요약 작성** (이 문서들).

## 배운 개념: Control Plane Taint

`notes/concepts.md` 참고. 요약: kubeadm init이 컨트롤 플레인에 자동으로 taint를 걸어 일반 워크로드를 배제(프로덕션 관례). Toleration이 없는 Pod는 스케줄 불가. 워커 1대뿐인 소규모 랩 환경에서는 taint를 제거해야 두 노드 모두에 워크로드가 분산되는 걸 확인할 수 있음.

## 현재 상태 (2026-09-15 기준)

- **kubeadm 클러스터**: `k8s-control`(control-plane, taint 없음) + `k8s-worker` 2노드, 둘 다 `Ready`. 검증용 리소스는 정리됨.
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림, 계속 별개로 유지.
- **🎉 17~21회차 "클러스터 직접 구성" 프로젝트 전체 완주**: VM 준비 → `kubeadm init` → Calico CNI → `kubeadm join` → 실제 워크로드로 검증까지, Docker Desktop이 숨겨왔던 클러스터 구축 전 과정을 손으로 완료.

## 다음에 이어서 할 만한 것 (방향 미정, 다음에 상의 필요)

- [ ] NetworkPolicy — Calico 위에서 Pod 간 트래픽 제어 실습 (지금 클러스터로 바로 해볼 수 있음)
- [ ] 기존 webapp/monitoring/argocd 프로젝트를 새 kubeadm 클러스터로 옮겨보기 (멀티노드 환경에서 재현)
- [ ] 클러스터 업그레이드(`kubeadm upgrade`) 실습 — 지금 클러스터가 실습 재료로 남아있음
- [ ] 심화 주제(Operator/CRD 직접 작성 등)
