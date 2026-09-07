# 2026-09-07 세션 요약 (15회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/14/session-summary.md](../14/session-summary.md))

## 오늘 한 일 순서

1. **"다음 방향 추천해줘" 요청** (14회차 완료 직후) — Prometheus + Grafana(모니터링 스택)를 추천, 채택. 이유: 14회차에서 배운 Helm으로 "남이 만든 공식 Chart" 설치를 처음 경험할 수 있고, 12회차 HPA를 시각적으로 재확인할 수 있어서.

2. **"진행해보자, 개념부터 설명해줘" 요청** — Prometheus/Grafana 개념 설명 (metrics-server와의 차이, kube-prometheus-stack, CRD/ServiceMonitor). `notes/concepts.md`에 정리.

3. **"만들어줘" 요청** — `notes/15/practice-guide.md` 작성 (Helm repo 추가 → kube-prometheus-stack 설치 → Grafana 접속 → 12회차 HPA 재현하며 실시간 그래프 관찰). README 갱신, 커밋+푸시.

4. **실습 진행** — 가이드를 보며 직접 실습, 이번 회차는 트러블슈팅이 여러 건 발생:
   - **4-1.** Step 1~2: Helm repo 추가, `kube-prometheus-stack` 설치 성공(약 2분, 예상보다 빠름), 6개 컴포넌트 전부 Running
   - **4-2.** Step 3~4: Grafana 로그인 시도 — "이메일 또는 사용자 이름" 필드를 구글 로그인으로 착각(설명해서 해소), 정확히 복사한 비밀번호로도 로그인 실패 → 서버 측(Secret/env var/로그) 전부 정상인데 원인 특정 안 됨 → `grafana cli admin reset-admin-password`로 강제 초기화해서 해결
   - **4-3.** 로그인 후 대시보드에 "No data" 발생 → 서버는 전부 정상, `kubectl port-forward` 연결 끊김이 원인으로 추정 → 재실행해서 해결
   - **4-4.** Step 5~6: 대시보드 기준선 확인, HPA 재적용
   - **4-5. (핵심, 트러블슈팅 반복)** Step 7: 부하 생성 Pod가 세 번의 시도 끝에 성공
     - 1차: 여러 줄 명령어 복사 중 깨져서 `StartError`
     - 2차: 한 줄로 바꿨으나 터미널 줄바꿈이 실제 개행으로 들어가 `syntax error`
     - 3차: YAML 파일로 전환, nano의 들여쓰기 문제까지 겹쳐 결국 Claude가 파일을 직접 작성해서 해결 — 이후 CPU 500%까지 치솟고 REPLICAS가 6까지 자동 확장되는 것을 Grafana 그래프와 kubectl 양쪽에서 동시에 확인
   - **4-6.** Step 8: 부하 제거 후 측정 지연을 거쳐 그래프/HPA 모두 최소치(1)까지 자동 축소되는 것 확인
   - **4-7.** Step 9: "정리하고 남겨둘게" 요청 — HPA 삭제, adminer 4개로 복구, port-forward 종료, 모니터링 스택은 유지

5. **완주 기록 저장** — `notes/15/practice-selfdone.md` 작성.

## 배운 개념: Prometheus + Grafana
`notes/concepts.md`에 정리됨. 요약: metrics-server(순간 스냅샷)와 달리 시계열로 지표를 쌓아 장기 추이·대시보드·알림 가능. `kube-prometheus-stack` Helm Chart로 한 번에 설치. ServiceMonitor 같은 CRD로 쿠버네티스 API 확장.

## 트러블슈팅 경험 (다시 겪을 수 있으니 참고)
- Grafana 로그인 실패 시 원인 불명이면 `grafana cli admin reset-admin-password <새 비밀번호>`로 강제 초기화하는 게 빠른 복구법
- `kubectl port-forward`는 오래 켜두면 연결이 끊길 수 있음 — 갑자기 "데이터 없음" 등 이상 증상 보이면 서버보다 포트포워드 연결부터 의심
- 긴 인라인 셸 명령어(`kubectl run ... -- sh -c "..."`)는 터미널 줄바꿈/복사 과정에서 쉽게 깨짐 — 반복 실패하면 YAML 파일로 작성해 `kubectl apply -f`하는 게 훨씬 안정적

## 현재 상태 (2026-09-07 기준)
- 클러스터: `webapp` Namespace(StatefulSet postgres, adminer 4개, Ingress) 그대로 유지. `monitoring` Namespace(Prometheus/Grafana 스택)도 요청대로 계속 유지.
- GitHub 레포: `main` 브랜치에 오늘 작업(개념, 가이드, 완주 기록) 전부 커밋/푸시 완료 예정

## 다음에 이어서 할 만한 것 (방향 미정, 다음에 상의 필요)
- [ ] 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s부터, kubeadm 멀티노드 구축
- [ ] NetworkPolicy, CI/CD 연동 등 추가 심화 주제
- [ ] webapp 프로젝트 추가 확장 (adminer 롤링 업데이트 재현 등)
