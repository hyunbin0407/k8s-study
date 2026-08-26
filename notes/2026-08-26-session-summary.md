# 2026-08-26 세션 요약

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [2026-08-24-session-summary.md](2026-08-24-session-summary.md))

## 오늘 한 일 순서

1. **다음 실습 요청** ("오늘 다음꺼 하고싶어 뭐할지 알려줘") — 다음 순서였던 **스케일링** 개념을 먼저 설명 (수동 `kubectl scale` / YAML 수정(선언적) / 자동 HPA, 롤링 업데이트와의 차이).

2. **"개념 정리해주고 실습가이드 만들어줘" 요청** — `notes/concepts.md`에 스케일링 섹션 추가, `notes/practice-03-guide.md` 작성, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **3-1.** 지난 실습에서 정리했던 nginx Deployment+Service 재배포 확인
   - **3-2.** `kubectl scale --replicas=5`로 수동 확장 → Pod 3→5개, **ReplicaSet은 새로 안 생기고 하나 그대로** `DESIRED 5`로 바뀌는 것 확인 (롤링 업데이트 때는 매번 새 ReplicaSet이 생겼던 것과 대조)
   - **3-3.** `kubectl scale --replicas=2`로 축소 — 1차 시도는 scale 실행 후 watch를 켜서 `Terminating` 과정을 놓침 (축소가 순식간에 끝남을 체감). 2차 시도로 watch를 먼저 켜놓고 scale 실행 → 3개 Pod가 **거의 동시에** `Terminating → Completed`되는 과정을 실시간 목격 (롤링 업데이트의 순차 교체와 다르게 스케일 다운은 한꺼번에 정리됨)
   - **3-4.** YAML 파일(`manifests/01-nginx-deployment.yaml`)의 `replicas`를 nano로 3→4로 직접 수정 후 `kubectl apply` → 선언적 방식 스케일링 확인
   - **3-5. (핵심)** `kubectl scale --replicas=7`로 명령어상 7개로 늘린 뒤, YAML은 그대로 두고 다시 `kubectl apply` → Pod가 YAML에 적힌 값(4개)으로 되돌아가는 것 확인. **명령형(imperative) 조작은 임시일 뿐, apply할 때마다 YAML(desired state)이 항상 이긴다**는 선언적 관리의 핵심을 직접 체감
   - **3-6.** YAML을 다시 `replicas: 3`으로 되돌리고 `kubectl delete -f`로 리소스 정리

4. **완주 기록 저장** — `notes/2026-08-26-practice-03-selfdone.md` 작성.

5. **"Docker Desktop에 남아있는 nodes/servers, 상관없냐" 질문** — `kubectl get nodes`, `kubectl get pods -A`로 직접 확인. `kube-system`(etcd, apiserver, controller-manager, scheduler, coredns, kube-proxy 등)과 `local-path-storage`는 **쿠버네티스 자체를 구동하는 필수 시스템 구성요소**라, 우리 실습 리소스(nginx) 정리와 무관하게 항상 떠 있는 게 정상이라고 안내. 실습 리소스는 완전히 깨끗하게 정리된 상태 확인.

6. **"오늘 대화 요약 저장해줘" 요청** — 이 세션 요약 파일(`2026-08-26-session-summary.md`) 작성.

## 아직 안 끝난 것 (다음에 확인 필요)
- [ ] 지난 세션 말미에 "다음 세션 요약 파일명을 번호 형식(예: '2회 세션요약')으로 바꿀지" 물어봤으나 **아직 답변을 못 받음** — 다음에 다시 물어보고 정해지면 그 형식으로 전환할 것. 그 전까지는 지금처럼 `YYYY-MM-DD-session-summary.md` 날짜 기반 파일명 유지.

## 현재 상태 (2026-08-26 기준)
- 클러스터: Kubernetes 활성화, 리소스는 정리되어 비어있음 (시스템 Pod만 존재, 정상)
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료

## 다음에 이어서 할 만한 것
- [ ] ConfigMap / Secret 개념 — 설정값을 코드와 분리하기 (다음 추천 순서)
- [ ] Namespace 개념
- [ ] Volume / PersistentVolume 개념 (스토리지)
- [ ] Ingress 개념
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축