# 2026-09-01 세션 요약 (8회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/07/session-summary.md](../07/session-summary.md))

## 오늘 한 일 순서

1. **"다음꺼 이어서 하자" 요청** — Ingress 개념 설명 (필요한 이유, Ingress vs Service 비교, Ingress Controller가 별도 설치 필요하다는 점).

2. **"실습 가이드 만들어줘" 요청** — `notes/concepts.md`에 Ingress 섹션 추가, `notes/08/practice-guide.md` 작성(Controller 설치 → nginx/httpd 두 앱 → 경로 기반 Ingress), README에 8회차 행 추가, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **3-1.** Step 1: Ingress Controller 설치. 처음엔 URL을 잘못 잘라서(디렉토리만) 404, 전체 경로로 정정해서 성공. Controller Pod Running 확인했지만 Service의 `EXTERNAL-IP`가 예상했던 `localhost`가 아니라 내부 IP(`172.18.0.5`)로 나옴 → `curl localhost:80`으로 직접 테스트해서 `404`(정상, 아직 Ingress 규칙 없어서) 확인, 실제로는 `localhost`로 잘 연결된다는 것 확인. 가이드의 부정확한 설명도 파악해 이후 수정
   - **3-2.** Step 2: nginx 스택(app1) 재배포, Service는 이전 실습 잔여물이 `unchanged`로 재사용됨
   - **3-3.** Step 3: httpd 기반 app2 신규 작성 및 배포
   - **3-4.** Step 4: 경로 기반 Ingress(`/app1`, `/app2`) 작성, `ADDRESS` 채워지는 것 확인
   - **3-5. (핵심 실험)** Step 5: `/app1/`은 nginx, `/app2/`는 처음엔 그레핑 패턴(`<h1>`)이 안 맞아 빈 결과 → 전체 응답 확인해서 실제로는 httpd(`<p>It works!</p>`)로 정상 라우팅되고 있었음을 확인
   - **3-6.** Step 6: Ingress 규칙만 수정(`/app2`의 backend를 nginx로 변경) → 앱 재배포 없이 라우팅만 바뀌는 것 확인
   - **3-7.** Step 7: "Ingress Controller는 남겨두고 정리는 네가 해줘" 요청 — Ingress/app2/nginx 스택만 삭제, 컨트롤러는 유지 (Claude가 대행)

4. **완주 기록 저장 + 가이드 수정** — `notes/08/practice-selfdone.md` 작성, `practice-guide.md`의 EXTERNAL-IP/grep 패턴 오류 수정.

## 배운 개념: Ingress
`notes/concepts.md`에 정리됨. 요약: 여러 Service를 도메인/경로 기준으로 하나의 진입점에서 라우팅. Ingress(규칙) + Ingress Controller(실제 프록시) 조합으로 동작하며 컨트롤러는 별도 설치 필요. L7(HTTP) 레벨이라 Service보다 세밀한 라우팅 가능.

## 트러블슈팅 경험 (다시 겪을 수 있으니 참고)
- Docker Desktop에서 `LoadBalancer` Service의 `EXTERNAL-IP`는 클러스터 내부 IP로 표시될 수 있음 — 실제 접속은 항상 `localhost`로. 화면에 보이는 IP를 곧이곧대로 믿지 말고 curl로 직접 확인하는 습관이 유용
- Ingress Controller가 매칭되는 규칙이 없을 때 기본 응답이 `404`인 것은 정상 동작
- 웹서버마다 기본 페이지의 HTML 마크업이 다름(nginx는 `<title>`, httpd는 `<p>`) — grep 패턴을 미리 단정하지 말고 전체 응답을 먼저 확인하는 게 안전

## 현재 상태 (2026-09-01 기준)
- 클러스터: `ingress-nginx` Namespace의 Controller는 계속 실행 중으로 남겨둠. 그 외(default Namespace의 nginx/httpd 스택)는 정리되어 비어있음
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료
- manifest 파일 목록: `01-nginx-deployment.yaml` ~ `06-nginx-pvc.yaml`(기존), `07-app2-deployment.yaml`, `08-app2-service.yaml`, `09-nginx-ingress.yaml`(오늘 추가)

## 다음에 이어서 할 만한 것
- 계획했던 핵심 개념(Pod~Ingress)은 이번 8회차로 전부 완료됨. 다음은 사용자와 상의해서 새 방향 결정 필요:
  - [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축
  - [ ] 또는 지금까지 배운 개념들을 종합하는 미니 프로젝트(예: 여러 컴포넌트로 구성된 앱을 처음부터 설계해서 배포)
  - [ ] 또는 각 개념을 더 깊이 파는 심화 학습(예: HPA 실습, RBAC, StatefulSet 등)
