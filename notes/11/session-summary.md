# 2026-09-03 세션 요약 (11회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/10/session-summary.md](../10/session-summary.md))

## 오늘 한 일 순서

1. **"다음 방향 정하자" 요청** → "어떤 방향이 좋을지 알려줘" → **"너가 추천하는 방향은 머야?"** — 심화 학습(HPA→StatefulSet→RBAC 순서)을 추천, StatefulSet부터 시작하기로 채택.

2. **"StatefulSet부터 시작하자" 요청** — 개념 설명 (Deployment와의 차이, `volumeClaimTemplates`, Headless Service, 우리 `webapp` 프로젝트의 postgres가 원래는 StatefulSet이었어야 하는 이유).

3. **"정리하고 기존 데이터 유지한 채로 전환하는 실습 가이드 만들어줘" 요청** — `notes/concepts.md`에 StatefulSet 섹션 추가, `notes/11/practice-guide.md` 작성(데이터 보존 마이그레이션 절차: PV Retain → PVC 삭제 → claimRef 제거 → 정확한 이름으로 PVC 재생성 → StatefulSet 생성), README 갱신, 커밋+푸시.

4. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **4-1.** Step 1: 작업 전 데이터 스냅샷 확인
   - **4-2.** Step 2: PV 회수 정책을 `Retain`으로 변경 (핵심 안전장치)
   - **4-3.** Step 3~4: 기존 Deployment/PVC 삭제, PV는 `Released`로 안전하게 보존됨 확인
   - **4-4.** Step 5: PV의 `claimRef` 제거 → `Available` 전환
   - **4-5.** Step 6: 새 이름의 PVC 작성 중 `volumeName` 플레이스홀더(`__PV_NAME__`)를 실제 값으로 안 바꾸고 그대로 적용하는 실수 발생 → 이후 값 수정 후 재적용했으나 `spec.volumeName`이 immutable이라 거부됨 → 잘못 생성된 PVC 삭제 후 재생성해서 해결
   - **4-6.** Step 7~8: Headless Service, StatefulSet 생성 → Pod 이름이 `postgres-0`으로 고정되는 것, 기존 PVC가 재사용(새로 안 만들어짐)되는 것 확인
   - **4-7.** Step 9: `notes` 테이블 데이터가 그대로 살아있는 것 확인 (핵심 목표 달성)
   - **4-8.** Step 10: `postgres-service`가 자동으로 새 Pod에 연결되는 것, adminer가 아무 설정 변경 없이 정상 작동하는 것 브라우저로 확인
   - **4-9.** Step 11: `postgres-0` Pod를 지웠다 재생성해도 같은 이름 유지, Headless Service DNS로 정확한 IP 조회, 데이터 세 번째 재확인까지 완료

5. **완주 기록 저장** — `notes/11/practice-selfdone.md` 작성.

## 배운 개념: StatefulSet
`notes/concepts.md`에 정리됨. 요약: Pod가 고정 이름(`<이름>-0`, `-1`...)과 개별 DNS(Headless Service)를 가지며, `volumeClaimTemplates`로 Pod마다 전용 PVC가 자동 생성됨. DB처럼 정체성·순서·전용 스토리지가 중요한 stateful 앱에 적합.

## 실전 마이그레이션 기법 (오늘의 핵심 배움)
살아있는 데이터를 Deployment→StatefulSet으로 옮기는 절차:
1. PV 회수 정책을 `Retain`으로 변경 (PVC 삭제해도 데이터 안 날아가게)
2. 기존 Deployment/PVC 삭제 (PV는 `Released`로 보존)
3. PV의 `claimRef` 제거 → `Available`로 되돌림
4. StatefulSet이 기대하는 정확한 이름(`<템플릿명>-<StatefulSet명>-<번호>`)으로 새 PVC를 `volumeName` 지정해서 재생성 → 기존 PV에 강제 바인딩
5. StatefulSet 생성 — 이미 있는 이름의 PVC를 발견하면 새로 안 만들고 재사용

## 현재 상태 (2026-09-03 기준)
- 클러스터: `webapp` Namespace에 StatefulSet 기반 postgres(`postgres-0`) + adminer(4 replica) + Ingress 전체가 살아있는 상태로 유지됨. `notes` 테이블 데이터 보존됨.
- GitHub 레포: `main` 브랜치에 오늘 작업(개념, 가이드, manifest, 완주 기록) 전부 커밋/푸시 완료 예정
- manifest 추가분: `manifests/project/11-postgres-pvc-migrated.yaml`, `12-postgres-headless-service.yaml`, `13-postgres-statefulset.yaml`. `05-postgres-deployment.yaml`은 더 이상 적용 안 하지만 기록용으로 보존.

## 다음에 이어서 할 만한 것
- [ ] HPA (자동 스케일링) — 심화 학습 순서상 다음 (metrics-server 설치 필요, 새로운 도전)
- [ ] RBAC (권한 관리) — 심화 학습 마지막 순서
- [ ] (선택) adminer 이미지 버전 변경으로 롤링 업데이트 재현
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s부터, kubeadm 멀티노드 구축
