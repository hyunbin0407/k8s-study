# 2026-09-01 세션 요약 (9회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/08/session-summary.md](../08/session-summary.md))

## 오늘 한 일 순서

1. **"다음 방향 추천해줘" 요청** (8회차 완료 직후) — 세 가지 후보(클러스터 직접 구성 / 미니 프로젝트 / 심화 학습) 중 **미니 프로젝트**를 추천. 이유: 지금까지 배운 8개 개념을 조합해서 실제로 써먹는 연습이 필요하고, 새 인프라 투자 없이 지금 환경 그대로 진행 가능하기 때문.

2. **"그 방향으로 진행해줘, 설계도 그려보자" 요청** — PostgreSQL(DB) + Adminer(웹 UI) 조합으로 2-tier 앱 설계 제안. 아키텍처 다이어그램, 컴포넌트별 상세, 배운 개념과의 매핑, 파일 구조까지 제시.

3. **"webapp로 하자" (Namespace 이름 확정)** — 설계를 `notes/09/design.md`로 문서화, README에 9회차 행 추가, 커밋+푸시.

## 설계 결정 사항
- Namespace: `webapp`
- 구성: `postgres-deployment`(1 replica, PVC로 데이터 유지) + `adminer-deployment`(2 replicas, stateless)
- ConfigMap/Secret으로 DB 설정·비밀번호 분리
- Ingress로 adminer 웹 UI를 `http://localhost/`에 노출 (8회차에서 설치해둔 ingress-nginx controller 재사용)
- manifest 파일은 기존처럼 `manifests/`에 번호로 안 쌓고 `manifests/project/`로 분리 예정

## 현재 상태 (2026-09-01 기준)
- 이번 회차는 **설계만** 진행, 실제 YAML 작성/배포는 아직 안 함
- 클러스터: `ingress-nginx` Controller는 계속 실행 중, 그 외엔 비어있음
- GitHub 레포: `main` 브랜치에 설계 문서 커밋/푸시 완료

## 다음에 이어서 할 만한 것
- [ ] `notes/09/design.md`에 정리된 순서대로 `manifests/project/` 안에 YAML 작성 및 `-n webapp`으로 배포
- [ ] Adminer 웹 UI 접속해서 테이블 생성/데이터 입력
- [ ] postgres Pod 삭제 후 재생성해도 데이터 유지되는지 확인 (PV 검증)
- [ ] adminer `kubectl scale`로 늘려서 여러 Pod가 같은 DB를 보는지 확인
- [ ] (선택) adminer 이미지 버전 변경으로 롤링 업데이트 재현
