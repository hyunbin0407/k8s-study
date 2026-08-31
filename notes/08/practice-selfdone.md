# 실습 08 — 직접 완주! Ingress

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Ingress Controller(nginx-ingress) 설치
   - 가이드에 안내된 URL 중 앞부분(디렉토리)으로 잘못 apply해서 404 발생 → 전체 파일 경로(`deploy/static/provider/cloud/deploy.yaml`)로 정정해서 성공
   - Controller Pod `Running` 확인, Service `TYPE: LoadBalancer`이지만 `EXTERNAL-IP`가 예상했던 `localhost`가 아니라 클러스터 내부 IP(`172.18.0.5`)로 나오는 것 발견
   - `curl http://localhost:80/`로 실제 접속 테스트 → `404` 응답 확인. 이게 정상 동작이라는 것 확인(Ingress 규칙이 아직 없어서 컨트롤러의 기본 404 응답이 나온 것) — Docker Desktop이 `EXTERNAL-IP` 표시와 무관하게 내부적으로 `localhost:80`을 컨트롤러로 매핑해준다는 것을 실험으로 확인. 가이드 문서의 부정확한 설명(EXTERNAL-IP가 localhost로 나온다는 부분)도 파악
2. 기존 nginx 스택(app1) 재배포 — Deployment/ConfigMap/Secret은 새로 생성, Service는 이전 실습에서 남아있던 것이 그대로 `unchanged`로 재사용됨
3. httpd 기반 두 번째 앱(app2) 신규 작성 — `manifests/07-app2-deployment.yaml`, `manifests/08-app2-service.yaml` → apply, Pod 2개 Running 확인
4. `manifests/09-nginx-ingress.yaml` 작성 — `/app1`, `/app2` 경로를 각각 nginx-service/app2-service로 라우팅, `rewrite-target`/`use-regex` 어노테이션으로 경로 접두어 제거
5. **핵심 실험**: `curl http://localhost/app1/`(nginx 페이지), `curl http://localhost/app2/`(httpd 페이지) → 같은 주소/포트인데 경로만 다르게 줘서 서로 다른 앱으로 라우팅되는 것 확인
   - `/app2/` 확인 시 가이드의 grep 패턴(`<h1>`)이 실제 httpd 기본 페이지 마크업(`<p>It works!</p>`)과 안 맞아서 빈 결과가 나왔던 것 발견 → 전체 응답으로 재확인해서 실제로는 정상 라우팅되고 있었음을 확인
6. Ingress 규칙만 수정(`/app2`의 backend를 `app2-service`→`nginx-service`로 변경) → 앱 재배포 없이 라우팅만 바뀌는 것 확인 (`/app2/`도 nginx 페이지로 응답)
7. 정리: Ingress Controller는 남겨두고("다음에 또 쓸 수도 있으니"), Ingress/app2/nginx 스택만 삭제 — Claude가 대행

## 배운 것 요약
- Ingress는 Ingress Controller(실제 프록시)가 설치되어 있어야 동작 — Deployment/Service처럼 기본 내장이 아님
- Docker Desktop에서 `LoadBalancer` 타입 Service의 `EXTERNAL-IP`는 내부 IP로 표시될 수 있지만, 실제로는 `localhost`로 접속해야 함 (표시된 IP를 곧이곧대로 믿지 말고 직접 curl로 확인하는 습관이 유용)
- Ingress Controller가 매칭되는 규칙이 없을 때 기본적으로 `404`를 반환한다는 것도 정상 동작으로 알아둘 것
- 같은 도메인/포트라도 경로(path)만으로 완전히 다른 백엔드 앱으로 라우팅 가능 — `rewrite-target` 없이는 백엔드가 경로 접두어를 몰라 404가 날 수 있음
- Ingress 규칙만 바꾸면 앱 재배포 없이도 트래픽 흐름을 바꿀 수 있음 (카나리 배포, 트래픽 전환 등에 활용되는 원리)
