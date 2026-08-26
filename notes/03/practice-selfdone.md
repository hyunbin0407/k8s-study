# 실습 03 — 직접 완주! 스케일링

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. 지난번 정리했던 nginx Deployment(3 replica) + Service 재배포
2. `kubectl scale --replicas=5`로 수동 확장 → Pod 3개→5개, ReplicaSet은 **새로 안 생기고 하나 그대로** `DESIRED 5`로 바뀌는 것 확인 (롤링 업데이트와의 차이점 확인)
3. `kubectl scale --replicas=2`로 축소
   - 1차 시도: scale 실행 후 watch를 켜서 `Terminating` 과정을 놓침 (이미 끝난 뒤 관찰 시작) — 축소가 매우 빠르게 끝난다는 것을 체감
   - 2차 시도: watch를 먼저 켜놓고 다른 터미널에서 scale 실행 → 3개 Pod가 거의 동시에 `Terminating → Completed`되는 과정을 실시간으로 목격 (롤링 업데이트 때 1개씩 순차 교체되던 것과 대조적으로, 스케일 다운은 한꺼번에 정리됨)
4. YAML 파일(`manifests/01-nginx-deployment.yaml`)의 `replicas`를 `nano`로 3→4로 직접 수정 후 `kubectl apply` → 선언적 방식으로 스케일링 확인 (2개→4개)
5. **선언적 관리 핵심 실험**: `kubectl scale --replicas=7`로 명령어상 7개로 늘린 뒤, YAML은 그대로 둔 채 다시 `kubectl apply` → Pod가 다시 YAML에 적힌 값(4개)으로 복귀하는 것 확인. `scale` 같은 명령형 조작은 임시 조치일 뿐, `apply`할 때마다 YAML(desired state)이 항상 이긴다는 것을 직접 체감
6. YAML을 다시 `replicas: 3`으로 되돌려놓고, `kubectl delete -f`로 리소스 정리
7. (부가 질문) Docker Desktop에 남아있는 노드/시스템 Pod(`kube-system`, `local-path-storage`)에 대해 확인 — 이건 K8s 자체를 구동하는 필수 구성요소라 실습 리소스 정리와 무관하게 항상 떠 있는 게 정상이라는 것 확인

## 배운 것 요약
- 스케일링은 이미지가 그대로라 **기존 ReplicaSet의 개수만** 조정됨 (새 ReplicaSet 안 생김) — 롤링 업데이트와의 핵심 차이
- 확장은 점진적, 축소는 한꺼번에 정리되는 경향 (안전장치 필요 없어서)
- `kubectl scale` 같은 명령형(imperative) 조작은 임시일 뿐, YAML(선언형/declarative)이 진짜 desired state — 다시 apply하면 YAML 값으로 수렴
- `kube-system`/`local-path-storage`의 시스템 Pod들은 우리가 만든 리소스와 무관한, 클러스터 자체의 필수 구성요소