# 실습 02 — 직접 완주! 롤링 업데이트 & 롤백

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. 지난번 정리했던 nginx Deployment(3 replica) + Service를 다시 `kubectl apply`로 배포
2. 이미지를 `latest` → `1.25`로 변경, `rollout status`로 완료 확인
3. 터미널 두 개로 실시간 관찰하며 `1.25` → `1.26` 롤링 업데이트 실행
   - `kubectl get pods -w`로 Pod가 **하나씩** `Pending → ContainerCreating → Running`으로 뜨고, 그 다음에야 기존 Pod 하나가 `Terminating`되는 순서를 직접 목격
   - `maxUnavailable: 1`, `maxSurge: 1` 기본값대로 동시에 1개씩만 교체되는 것 확인
4. 결과 검증: Pod 이름이 새 ReplicaSet 소속으로 전부 교체, 이미지 `1.26` 확인, replicas 수는 3개로 유지
5. `kubectl get replicaset`으로 예전 ReplicaSet들이 `DESIRED 0`으로 이력에 남아있는 것 확인 (롤백의 원리)
6. `kubectl rollout history`로 리비전 이력(1, 2, 3) 확인 — `CHANGE-CAUSE`는 기본적으로 `<none>`이라는 것도 확인
7. `kubectl rollout undo`로 `1.26` → `1.25` 롤백 성공 (경고 메시지: `kubectl apply`로 관리되던 리소스라 `last-applied-configuration` 어노테이션이 갱신 안 된다는 안내 — 정상, 무시 가능)
   - 롤백 후 리비전 번호가 `2`가 아니라 새 리비전(`4`)으로 추가되는 것 확인 (되돌린 게 아니라 "이전 설정으로 새 리비전 추가" 방식)
8. **실패 시나리오 실습**: 존재하지 않는 이미지 태그(`nginx:this-tag-does-not-exist`)로 업데이트 시도
   - 새 Pod가 `ImagePullBackOff`로 멈춘 동안 기존 정상 Pod 3개는 전혀 안 내려가고 계속 서비스 중인 것 확인 → 롤링 업데이트의 안전성 직접 체감
   - `rollout undo`로 복구. 이번엔 기존 Pod가 애초에 안 흔들렸어서 Pod 이름/AGE가 그대로 유지된 채로 실패한 새 ReplicaSet만 제거됨
9. `kubectl delete -f`로 리소스 정리 완료 (현재 클러스터는 비어있는 상태)

## 배운 것 요약
- 롤링 업데이트는 새 ReplicaSet을 늘리고 기존 ReplicaSet을 줄이는 방식으로 진행되며, `maxSurge`/`maxUnavailable`로 속도·안전성을 조절
- 롤백은 예전 ReplicaSet 설정으로 새 리비전을 추가하는 방식 (리비전 번호는 항상 증가)
- 새 Pod가 `Ready`가 안 되면 기존 Pod를 내리지 않아 배포 실패가 곧 서비스 장애로 이어지지 않음