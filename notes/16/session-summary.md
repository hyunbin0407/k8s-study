# 2026-09-09 세션 요약 (16회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/15/session-summary.md](../15/session-summary.md))

## 오늘 한 일 순서

1. **"다음 방향 정하자" 요청** — GitOps(ArgoCD)를 추천, 채택. 이유: 14회차 Helm Chart를 실전 활용할 수 있고, 로컬/비공개 클러스터 환경에 실제로 적용 가능한(Pull 방식) CI/CD 대안이라서. 일반적인 Push 기반 CI/CD(GitHub Actions 직접 배포)는 이 환경에서 기술적으로 불가능하다는 점도 설명.

2. **"진행하자, 개념부터 설명해줘" 요청** — GitOps/ArgoCD 개념 설명 (Pull vs Push 방식 비교, Application CRD, selfHeal). `notes/concepts.md`에 정리.

3. **"정리하고 실습가이드 만들어줘" 요청** — `notes/16/practice-guide.md` 작성 (ArgoCD 설치 → Application으로 우리 GitHub 레포 감시 → git push로 자동 배포 확인 → kubectl로 수동 변경 시 self-heal 확인). 레포가 공개 상태인지 사전 확인. README 갱신, 커밋+푸시.

4. **실습 진행** — 가이드를 보며 직접 실습, 오늘도 오류 없이 순조롭게 완주:
   - **4-1.** Step 1: ArgoCD Helm 설치, 7개 컴포넌트 약 30초 만에 Running
   - **4-2.** Step 2~3: 관리자 비밀번호 확인(15회차 Grafana와 동일 패턴), port-forward 접속 시 자체 서명 인증서 경고 발생 → 크롬에서 우회하는 방법 안내해서 해결
   - **4-3.** Step 4~5: `Application` 리소스로 우리 GitHub 레포의 `helm/webapp-chart`를 감시하도록 설정 → `kubectl`/`helm` 직접 실행 없이 `webapp-gitops` Namespace에 전체 스택 자동 배포 확인
   - **4-4. (핵심)** Step 6: `values.yaml`의 `adminer.replicas`를 4→2로 수정 후 git push만 실행 → 클러스터가 자동으로 따라가는 것 확인
   - **4-5. (핵심)** Step 7: `kubectl scale --replicas=5`로 수동 변경 시도 → ArgoCD의 self-heal이 즉시 Git 상태(2개)로 되돌리는 것 확인
   - **4-6.** Step 8: "네가 정리해주고 ArgoCD는 남겨둘게" 요청 — Application/webapp-gitops Namespace 삭제, values.yaml을 4로 복구해 커밋+푸시까지 Claude가 대행. ArgoCD 자체와 기존 webapp/monitoring은 유지

5. **완주 기록 저장** — `notes/16/practice-selfdone.md` 작성.

## 배운 개념: GitOps / ArgoCD
`notes/concepts.md`에 정리됨. 요약: Git을 원하는 상태의 유일한 기준으로 삼고 클러스터 내부 에이전트가 Pull 방식으로 동기화. `Application` CRD로 감시 대상(레포+경로) 정의. `selfHeal: true`로 수동 변경도 자동 복구되는, 선언적 관리의 가장 강력한 형태.

## 현재 상태 (2026-09-09 기준)
- 클러스터: `webapp`(원본 프로젝트), `monitoring`(Prometheus/Grafana), `argocd`(GitOps 도구) 세 Namespace가 계속 살아있는 상태로 유지. `webapp-gitops`는 실습 종료 후 정리됨.
- `helm/webapp-chart/values.yaml`은 `adminer.replicas: 4`로 원상 복구되어 있음
- GitHub 레포: `main` 브랜치에 오늘 작업(개념, 가이드, values.yaml 변경 2건, 완주 기록) 전부 커밋/푸시 완료 예정

## 다음에 이어서 할 만한 것 (방향 미정, 다음에 상의 필요)
- [ ] 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s부터, kubeadm 멀티노드 구축
- [ ] NetworkPolicy 등 추가 심화 주제
- [ ] webapp 프로젝트 추가 확장 (adminer 롤링 업데이트 재현 등)
