# 실습 11 — 직접 완주! postgres를 Deployment → StatefulSet으로 전환 (데이터 유지)

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Step 1: 작업 전 데이터 스냅샷 확인 (`notes` 테이블, `첫번째 메모` 1건)
2. Step 2: PV(`pvc-ee193bdc-...`)의 회수 정책을 `Delete → Retain`으로 변경 (가장 중요한 안전장치)
3. Step 3: 기존 `postgres-deployment` 삭제 → Pod 사라짐, PVC/데이터는 그대로 유지
4. Step 4: 기존 `postgres-pvc` 삭제 → PV는 삭제 안 되고 `Released` 상태로 보존됨 (Retain 정책 덕분)
5. Step 5: PV의 `claimRef` 제거(`kubectl patch ... --type=json`) → `STATUS: Available`로 전환
6. Step 6: StatefulSet이 기대하는 이름(`postgres-storage-postgres-0`)으로 새 PVC 작성, `volumeName`으로 기존 PV에 강제 연결
   - 1차 시도에서 YAML의 `volumeName` 자리에 안내 문구(`__PV_NAME__`)를 실제 값으로 안 바꾸고 그대로 적용해버림 → apply는 됐지만 PVC가 `Pending`으로 멈춤
   - 파일을 실제 PV 이름으로 수정 후 재적용했으나, PVC의 `spec.volumeName`은 생성 후 수정 불가(immutable)라 `kubectl apply`가 거부됨 → 잘못 생성된(어차피 아무 데이터와도 연결 안 된) PVC를 삭제하고 파일을 다시 apply해서 정상 `Bound` 확인
7. Step 7: Headless Service(`postgres-headless`, `clusterIP: None`) 생성
8. Step 8: StatefulSet(`postgres`, `serviceName: postgres-headless`, `volumeClaimTemplates`) 생성
   - Pod가 랜덤 해시가 아니라 정확히 `postgres-0`이라는 고정 이름으로 뜨는 것 확인
   - `postgres-storage-postgres-0` PVC의 AGE가 StatefulSet 생성 시점보다 훨씬 오래된 것으로, 새로 안 만들고 Step 6에서 준비해둔 PVC를 그대로 재사용했다는 것 확인
9. Step 9: `postgres-0`에서 `SELECT * FROM notes;` → `첫번째 메모` 데이터 그대로 확인 (이번 실습의 핵심 목표 달성)
10. Step 10: `postgres-service`(기존 ClusterIP)의 endpoint가 자동으로 새 Pod(`postgres-0`)의 IP로 갱신된 것 확인, 아무 설정도 안 바꿨는데 adminer가 자동으로 붙는 것을 브라우저에서 실제로 확인
11. Step 11: `postgres-0` Pod를 강제 삭제 후 재생성 → 여전히 `postgres-0`이라는 같은 이름으로 뜨는 것 확인, Headless Service의 DNS(`postgres-0.postgres-headless.webapp.svc.cluster.local`)로 조회한 IP가 실제 새 Pod IP와 정확히 일치하는 것 확인, 데이터도 세 번째로 재확인해서 안전함을 재차 검증
12. 정리는 하지 않음 — 데이터를 계속 살려서 쓸 것이므로 이 상태 그대로 유지. 예전 `05-postgres-deployment.yaml`은 더 이상 적용하지 않지만 기록용으로 보존

## 배운 것 요약
- StatefulSet은 Deployment와 달리 Pod 이름이 고정(`<이름>-0`, `-1`...)되고, Headless Service를 통해 각 Pod에 안정적인 개별 DNS 이름이 부여됨
- `volumeClaimTemplates`을 쓰면 Pod마다 전용 PVC가 자동 생성되지만, **이미 존재하는 이름의 PVC가 있으면 새로 안 만들고 그대로 재사용**한다는 점을 이용해 살아있는 데이터를 Deployment→StatefulSet으로 마이그레이션할 수 있음
- PV를 재사용하려면: ① 회수 정책을 `Retain`으로 미리 바꿔서 PVC 삭제 시 데이터 보호 → ② 기존 PVC 삭제 → ③ PV의 `claimRef` 제거해서 `Available` 상태로 되돌림 → ④ 새 PVC를 정확한 이름 + `volumeName` 지정으로 만들어 강제 바인딩, 순서로 진행
- PVC의 `spec.volumeName` 등 핵심 스펙은 생성 후 수정 불가(immutable) — 값을 잘못 넣었으면 삭제 후 재생성해야 함
- Service의 라벨 셀렉터 방식은 뒤에 있는 게 Deployment든 StatefulSet이든 상관없이 동일하게 작동 — 오브젝트 종류를 바꿔도 클라이언트(adminer) 쪽은 아무 변경이 필요 없었음
