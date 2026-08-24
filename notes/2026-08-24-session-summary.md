# 2026-08-24 세션 요약

오늘 진행한 흐름 요약. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [2026-08-23-session-summary.md](2026-08-23-session-summary.md))

## 학습 방식 (계속 유지 중)
- 개념 먼저 배우고, 그다음 손으로 직접 실습하는 순서 선호
- 실습은 Claude가 대신 실행하지 않고 본인이 직접 `kubectl`/에디터로 타이핑하며 진행
  → Claude는 가이드 제공 + 결과 검증(확인)만 담당
- 개념/실습 내용은 매번 정리 후 커밋+푸시하는 루틴 유지

## 오늘 있었던 대화: 인프라 구성 실습에 대한 질문
- "인프라 구성하는 실습(클러스터 자체를 만드는 것)은 지금 하기엔 이르지 않냐"는 질문
- 답: 맞음. 지금까지 배운 건 전부 "이미 만들어진 클러스터 위에 앱을 배포하는 법"이고,
  클러스터 자체 구성(리눅스/네트워킹/kubeadm/클라우드 등)은 별도 지식 트랙 필요
- 그래서 예전에 concepts.md에서 매니지드 K8s/kubeadm 섹션을 삭제했던 게 맞는 판단이었다고 확인
- **결론**: 당분간은 계속 "기존 클러스터 위에서 앱 운영 개념"을 쌓는 방향으로 진행 (롤링 업데이트 → 스케일링 → ConfigMap/Secret → Namespace → Volume → Ingress 순), 클러스터 직접 구축은 나중에 별도로 다루기로 함

## 배운 개념: 롤링 업데이트 (Rolling Update)
`notes/concepts.md`에 추가됨. 요약:
- Deployment 이미지 버전 변경 시 Pod를 한꺼번에 안 바꾸고 순차 교체 → 무중단 배포
- 새 ReplicaSet을 늘리고 기존 ReplicaSet을 줄이는 방식으로 진행
- `maxUnavailable`/`maxSurge`(기본 각 25%)로 교체 속도·안전성 조절
- 관련 명령어: `kubectl set image`, `rollout status`, `rollout history`, `rollout undo`

## 완료한 실습 — 실습 02: 롤링 업데이트 & 롤백
- 관련 파일: [practice-02-guide.md](practice-02-guide.md) (가이드), [2026-08-24-practice-02-selfdone.md](2026-08-24-practice-02-selfdone.md) (직접 완주 기록)
- 지난 실습에서 정리했던 nginx Deployment+Service를 재배포하는 것부터 시작
- 이미지 `latest → 1.25 → 1.26` 순차 업데이트, 터미널 두 개(`-w` 관찰 + 실제 업데이트)로 Pod가 **하나씩** 교체되는 과정을 실시간 목격
- `kubectl get replicaset`으로 예전 ReplicaSet들이 `DESIRED 0`으로 이력에 남는 것 확인 (롤백 원리)
- `kubectl rollout history`로 리비전 이력 확인, `CHANGE-CAUSE`는 기본 `<none>`이라는 것도 확인
- `kubectl rollout undo`로 롤백 성공 — 리비전 번호가 되돌아가는 게 아니라 새 리비전으로 추가되는 방식임을 확인
- **실패 시나리오**: 존재하지 않는 이미지 태그로 업데이트 시도 → 새 Pod는 `ImagePullBackOff`로 대기, 기존 정상 Pod 3개는 전혀 안 내려가고 서비스 유지되는 것 직접 확인 (롤링 업데이트의 안전성 체감)
- `kubectl rollout undo`로 재복구, `kubectl delete -f`로 리소스 정리 완료 (현재 클러스터는 비어있는 상태)

## 현재 상태 (2026-08-24 기준)
- 클러스터: Kubernetes 활성화되어 있음, 리소스는 정리되어 비어있음
- GitHub 레포: `main` 브랜치에 위 내용 전부 커밋/푸시 완료

## 다음에 이어서 할 만한 것
- [ ] 스케일링 실습 (`kubectl scale`로 Pod 개수 조절) — 다음 추천 순서
- [ ] ConfigMap / Secret 개념 — 설정값을 코드와 분리하기
- [ ] Namespace 개념
- [ ] Volume / PersistentVolume 개념 (스토리지)
- [ ] Ingress 개념 (Service보다 상위의 외부 노출 방식)
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축