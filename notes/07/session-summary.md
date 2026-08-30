# 2026-08-30 세션 요약 (7회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/06/session-summary.md](../06/session-summary.md))

## 오늘 한 일 순서

1. **"7회차 진행하자" 요청** — Volume/PersistentVolume 개념 설명 (Volume vs PV 차이, PV/PVC 구조, `local-path-provisioner`의 동적 프로비저닝).

2. **"정리하고 실습 가이드 만들어줘" 요청** — `notes/concepts.md`에 Volume/PersistentVolume 섹션 추가, `notes/07/practice-guide.md` 작성, README에 7회차 행 추가, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **3-1.** Step 1: PVC(`nginx-pvc`) 작성 → `Pending` 상태 확인 (WaitForFirstConsumer라 정상)
   - **3-2.** Step 2: Deployment에 PVC 마운트 + replicas 3→1 축소 시도 중 두 가지 문제 발생
     - nano 탭 문자 에러 (지난 Secret 실습과 동일 패턴) + `volumeMounts`에 `html-storage` 항목 누락 — 확인 후 수정
     - apply는 됐지만 Pod가 `ContainerCreating`에 멈춤 → `configmap "nginx-config" not found` 원인 발견, 가이드의 준비 단계에 ConfigMap/Secret 적용 안내가 빠져있던 실수를 확인하고 즉시 적용 + 가이드 문서 수정
     - PVC가 `Bound`로 전환, PV 자동 생성 확인
   - **3-3.** Step 3: `kubectl exec`로 커스텀 `index.html` 작성, `cat`/`curl`로 확인
   - **3-4. (핵심 실험)** Step 4~5를 합쳐서 진행: Deployment 전체 삭제 → PVC는 `Bound` 유지 확인 → 재생성 → 새 Pod에서도 데이터가 그대로 남아있는 것 확인 (Pod/Deployment 삭제와 무관하게 PVC에 데이터가 종속됨을 확인)
   - **3-5.** Step 6: PVC 삭제 → 연결된 PV도 함께 자동 삭제되는 것 확인 (`ReclaimPolicy: Delete`)
   - **3-6.** Step 7: "네가 정리해줘" 요청으로 이번엔 제가 대신 정리 — 남은 ConfigMap/Secret 삭제, `manifests/01-nginx-deployment.yaml`을 원래 상태(`replicas: 3`, PVC 볼륨 제거)로 복원

4. **완주 기록 저장** — `notes/07/practice-selfdone.md` 작성.

## 배운 개념: Volume / PersistentVolume
`notes/concepts.md`에 정리됨. 요약: Volume은 Pod 생명주기에 종속, PersistentVolume은 독립적으로 존재. PVC로 용량만 요청하면 K8s(local-path-provisioner)가 알아서 PV를 만들어 연결. 데이터는 PVC에 종속되므로 Pod/Deployment를 지웠다 다시 만들어도 유지되지만, PVC 자체를 지우면 `ReclaimPolicy`에 따라 데이터까지 삭제될 수 있음.

## 트러블슈팅 경험 (다시 겪을 수 있으니 참고)
- 가이드/YAML 작성 시 여러 리소스가 서로 참조하는 경우(Deployment가 ConfigMap/Secret 참조), 의존하는 리소스를 먼저 적용해야 함 — 순서를 빠뜨리면 `FailedMount`류 에러 발생
- nano 자동 들여쓰기로 인한 탭 문자 혼입은 계속 나올 수 있는 패턴 — `kubectl apply --dry-run=client`로 사전 검증하는 습관이 유효

## 현재 상태 (2026-08-30 기준)
- 클러스터: Kubernetes 활성화, 리소스는 정리되어 비어있음 (PVC/PV도 완전히 삭제됨)
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료 (가이드 수정 포함)
- manifest 파일 목록: `01-nginx-deployment.yaml`(원래 상태로 복원됨), `02-nginx-service.yaml`, `03-nginx-configmap.yaml`, `04-nginx-secret.yaml`, `05-dev-namespace.yaml`, `06-nginx-pvc.yaml`

## 다음에 이어서 할 만한 것
- [ ] Ingress 개념 — Service보다 상위의 외부 노출 방식 (다음 추천 순서, 남은 마지막 핵심 개념)
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축
