# 실습 10 — 직접 완주! 미니 프로젝트 구현 (webapp: PostgreSQL + Adminer)

가이드: [practice-guide.md](practice-guide.md) · 설계: [../09/design.md](../09/design.md)

## 진행 내용

1. `manifests/project/` 폴더 생성, 기존 ingress-nginx controller(8회차 설치분) 재사용 확인
2. Step 1: `webapp` Namespace 생성, `kubectl config set-context --current --namespace=webapp`로 기본 Namespace 전환
3. Step 2~4: postgres용 ConfigMap(`POSTGRES_DB`, `POSTGRES_USER`), Secret(`POSTGRES_PASSWORD`), PVC(1Gi) 작성·적용 — PVC는 예상대로 `Pending`
4. Step 5: postgres Deployment(`subPath: pgdata` 사용) + Service 적용 → Pod Running, PVC `Bound`로 전환, 로그로 `database system is ready to accept connections`까지 확인
5. Step 6~7: adminer용 ConfigMap(`ADMINER_DEFAULT_SERVER: postgres-service`), Deployment(`replicas: 2`) + Service 적용 → Pod 2개 Running
6. Step 8: Ingress(`path: /` → adminer-service) 적용, `ADDRESS` 채워짐, `curl http://localhost/` → `200` 확인

## 트러블슈팅 — 로그인 세션 문제 (이번 실습에서 가장 깊게 다룬 부분)

7. Step 9에서 브라우저로 로그인 시도 → "계속 버퍼링만 되고 로그인이 안 됨" 증상 발생. 원인 조사 과정:
   - Ingress Controller의 `EXTERNAL-IP`가 `localhost`가 아니라 내부 IP로 표시되는 것부터 확인(8회차와 동일 패턴, 문제 아님)
   - postgres/adminer 로그 확인 → 처음엔 로그인 성공(302→200) 후 이후 요청에서 반복적으로 `403` 발생하는 패턴 발견
   - adminer를 `replicas: 1`로 임시로 줄여도 여전히 403 발생 → 세션 문제가 아니라는 것으로 착각하고 다른 원인(postgres 인증 타임아웃, Ingress/네트워크 conntrack 콜드스타트 등)을 curl/nc로 정밀하게 측정하며 조사했으나 모두 정상으로 확인됨
   - 이후 사용자가 로그인 폼의 "System" 필드를 PostgreSQL로 선택하지 않았던 실수를 발견 → adminer를 다시 `replicas: 2`(원래 설계)로 복구
   - 로그인은 됐지만 "테이블 이름"에 버튼 텍스트(`Create table`)가 그대로 들어간 실수로 빈 테이블 생성됨 → 삭제 후 재생성 안내
   - 이후 "페이지 이동하면 계속 로그아웃됨", "잘못된 CSRF 토큰입니다" 증상이 다시 발생 → **진짜 원인**: adminer `replicas: 2` + Service 로드밸런싱으로 세션이 Pod마다 따로 저장되는 문제였음이 로그 분석(같은 요청이 두 Pod에 번갈아 찍힘)으로 최종 확인
   - 1차 시도: `adminer-service`에 `sessionAffinity: ClientIP` 추가 → **효과 없음** (원인: Ingress Controller가 Service/kube-proxy를 거치지 않고 Pod에 직접 연결하기 때문)
   - 2차 시도(성공): `webapp-ingress`에 `nginx.ingress.kubernetes.io/affinity: cookie` 등 sticky session 어노테이션 추가 → curl로 쿠키 재사용 시 항상 같은 Pod로 고정되는 것을 검증 → 실제 브라우저 로그인도 정상화

8. `notes` 테이블(`id` 자동증가, `content` 텍스트)을 다시 정확한 이름으로 생성, 데이터(`첫번째 메모`) 입력 및 저장까지 완료. `psql`로 직접 DB 조회해서 실제 저장 확인
9. Step 10: postgres Pod 삭제 → 새 Pod로 교체돼도 `notes` 테이블과 데이터가 그대로 남아있는 것 확인 (PVC 검증, 7회차 실험 실제 데이터로 재현)
10. Step 11: adminer를 `replicas: 4`로 확장 → 4개 Pod 전부 Running, sticky session 쿠키가 있는 요청은 한 Pod로 고정되고 쿠키 없는 새 요청은 여러 Pod로 분산되는 것을 curl로 검증. 어느 Pod를 거치든 같은 postgres 데이터를 보는 것이 이번 프로젝트의 핵심 목표

11. Step 12(정리)는 보류 — 사용자 요청으로 `webapp` 리소스는 현재 상태 그대로 유지, 실습 가이드만 오늘 겪은 오류를 반영해 수정

## 가이드 문서 수정 사항
- Step 7(adminer Service)에 `sessionAffinity: ClientIP` 추가 + 이게 Ingress 트래픽엔 안 먹힌다는 설명 보강
- Step 8(Ingress)에 처음부터 sticky session 어노테이션(`nginx.ingress.kubernetes.io/affinity: cookie` 등) 포함하도록 수정 + 이유 설명 추가
- Step 9에 "테이블 이름" 입력창 위치 팁, CSRF 토큰 경고 원인/대처 추가
- Step 11에 sticky session 쿠키 때문에 같은 탭에서는 항상 같은 Pod로 연결된다는 점, 다른 Pod로 확인하려면 시크릿 모드를 쓰라는 안내 추가
- "트러블슈팅 노트" 표 신설 (증상/원인/해결 정리)

## 배운 것 요약
- Service의 `sessionAffinity`는 Service(kube-proxy)를 거치는 트래픽에만 적용되고, **Ingress Controller는 성능을 위해 Pod에 직접 연결**하므로 무시됨 — 세션이 필요한 앱을 Ingress 뒤에 여러 개 띄울 땐 Ingress 자체의 sticky session 기능을 써야 함
- 문제 원인을 좁힐 때 "재현되는 조건"을 하나씩 통제해서 바꿔가며(replicas 수, curl 직접 테스트 등) 검증하는 게 중요하다는 것을 실전에서 체감 — 처음엔 postgres 인증 타임아웃, 네트워크 콜드스타트 등 잘못된 가설도 세워봤지만 로그와 curl 재현으로 하나씩 배제해나감
- `kubectl logs`에서 여러 Pod의 로그를 나란히 비교하면 로드밸런싱/세션 문제를 확인하는 데 효과적
- PV(7회차)와 스케일링(3회차) 개념이 실제 데이터를 가진 앱에서도 똑같이 작동한다는 것을 재확인
- 지금까지 배운 8개 개념(Namespace, ConfigMap, Secret, Deployment+Service, PV, Ingress, 스케일링, 롤링 업데이트 — Ingress 어노테이션 재적용 자체도 일종의 롤링 업데이트)이 전부 하나의 프로젝트 안에서 실제로 맞물려 동작하는 것을 확인
