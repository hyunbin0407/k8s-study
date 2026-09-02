# 2026-09-02 세션 요약 (10회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/09/session-summary.md](../09/session-summary.md))

## 오늘 한 일 순서

1. **"구현 시작하자" 요청** — 9회차 설계도 그대로 `notes/10/practice-guide.md` 작성(Namespace → ConfigMap/Secret/PVC → postgres → adminer → Ingress → 브라우저 검증 → PV/스케일링 검증), README 갱신, 커밋+푸시.

2. **실습 진행 (Step 1~8)** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행. Namespace, ConfigMap×2, Secret, PVC, postgres Deployment+Service, adminer Deployment+Service, Ingress까지 순조롭게 배포 완료 (`curl http://localhost/` → 200 확인).

3. **Step 9 트러블슈팅 — 로그인이 계속 안 됨** — 긴 진단 과정 진행:
   - 로그 분석으로 초반엔 로그인 성공 후 반복 403 패턴 발견
   - adminer를 1개로 줄여도 여전히 403 → 세션 문제가 아니라고 오판, postgres 인증 타임아웃/Ingress·네트워크 콜드스타트 등을 curl·nc로 정밀 조사했으나 전부 정상으로 확인됨 (헛다리)
   - 사용자가 로그인 폼의 "System" 필드를 PostgreSQL로 선택 안 했던 실수를 뒤늦게 발견 → adminer를 다시 원래 설계(`replicas: 2`)로 복구
   - 로그인은 됐지만 "테이블 이름"에 버튼 텍스트가 그대로 들어가 빈 테이블(`Create table`)이 생성되는 실수 → 삭제 후 재안내
   - 이후 "페이지 이동하면 로그아웃됨", "CSRF 토큰 오류" 재발 → 로그로 같은 요청이 두 Pod에 번갈아 찍히는 것을 확인해 **진짜 원인이 세션/로드밸런싱 문제**였음을 최종 확정
   - 1차 해결 시도: `adminer-service`에 `sessionAffinity: ClientIP` 추가 → 효과 없음 확인 (Ingress가 Service를 안 거치고 Pod에 직접 연결하기 때문)
   - 2차 해결(성공): `webapp-ingress`에 `nginx.ingress.kubernetes.io/affinity: cookie` 등 sticky session 어노테이션 추가 → curl로 검증 후 브라우저에서도 정상화

4. **테이블/데이터 재작업** — `notes` 테이블(정확한 이름으로) 재생성, 데이터(`첫번째 메모`) 입력·저장 성공, `psql`로 직접 검증.

5. **Step 10 (PV 검증)** — postgres Pod 삭제 후 재생성해도 `notes` 테이블+데이터가 그대로 남아있는 것 확인 (7회차 실험을 실제 데이터로 재현).

6. **Step 11 (스케일링 검증)** — adminer를 `replicas: 4`로 확장, sticky 쿠키가 있으면 한 Pod로 고정되고 새 쿠키는 여러 Pod로 분산되는 것을 curl로 검증. 어느 Pod를 거치든 같은 postgres 데이터를 보는 것 확인.

7. **"이 상태로 남겨두고 오늘 실습 기록 정리해줘, 오류였던 부분들은 가이드도 고쳐줘" 요청** — `webapp` 리소스는 정리하지 않고 그대로 유지. `notes/10/practice-guide.md`를 실제로 겪은 문제에 맞게 수정:
   - Step 7에 `sessionAffinity: ClientIP` 추가 + Ingress엔 안 먹힌다는 설명
   - Step 8 Ingress YAML에 처음부터 sticky session 어노테이션 포함하도록 수정 + 이유 설명
   - Step 9에 테이블 이름 입력 위치 팁, CSRF 경고 대처법 추가
   - Step 11에 sticky 쿠키로 인한 새로고침 동작 설명 보강
   - "트러블슈팅 노트" 표 신설
   - `notes/10/practice-selfdone.md` 작성

## 배운 것
- Service의 `sessionAffinity`는 kube-proxy를 거치는 트래픽에만 적용되고, Ingress Controller는 성능을 위해 Pod에 직접 연결하므로 무시됨 — 세션이 필요한 앱은 **Ingress 레벨**의 sticky session(`affinity: cookie`)을 써야 함
- 여러 유력한 가설(DB 인증 타임아웃, 네트워크 콜드스타트)을 curl/로그로 하나씩 검증하며 배제해나가는 실전 디버깅 과정을 경험함
- PV(7회차)와 스케일링(3회차)이 실제 데이터를 가진 앱에서도 똑같이 작동하는 것을 재확인

## 현재 상태 (2026-09-02 기준)
- 클러스터: `webapp` Namespace에 전체 스택(Namespace/ConfigMap×2/Secret/PVC/postgres/adminer×4/Ingress)이 **살아있는 상태로 유지됨** (사용자 요청으로 정리 안 함). `notes` 테이블에 데이터 1건 존재.
- GitHub 레포: `main` 브랜치에 오늘 작업한 manifest, 가이드 수정, 완주 기록 전부 커밋/푸시 완료 예정
- `ingress-nginx` Controller는 계속 실행 중

## 다음에 이어서 할 만한 것
- [ ] (선택) `kubectl delete namespace webapp`로 미니 프로젝트 정리 — 원할 때 아무 때나
- [ ] (선택) adminer 이미지 버전을 바꿔서 롤링 업데이트 재현 (설계 문서에 있던 마지막 미완료 항목)
- [ ] 미니 프로젝트 이후 새 방향 — 클러스터 직접 구성(리눅스/네트워킹 또는 매니지드 K8s부터, kubeadm 멀티노드) 또는 심화 학습(HPA, RBAC, StatefulSet 등) 중 선택 필요
