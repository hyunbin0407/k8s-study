# 2026-09-07 세션 요약 (14회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/13/session-summary.md](../13/session-summary.md))

## 오늘 한 일 순서

1. **"다음 방향 추천 해줘" 요청** — 심화 학습 트랙(StatefulSet/HPA/RBAC) 완료 직후, Helm(패키지 매니저)을 추천 (webapp 프로젝트의 18개 YAML을 하나의 재사용 가능한 Chart로 재구성하는 방향).

2. **"진행하자 개념부터 설명해줘" 요청** — Helm 개념 설명 (Chart/Values/Template/Release/Repository, `helm rollout undo`와의 비교), `notes/concepts.md`에 정리. 로컬에 Helm CLI가 설치 안 되어 있는 것 확인.

3. **"만들어줘" 요청** — `notes/14/practice-guide.md` 작성 (Helm 설치 → 기존 `webapp` 프로젝트는 안 건드리고 새 Namespace `webapp-helm`에 Chart로 재배포하는 안전한 설계 — 10회차 sticky session 교훈을 처음부터 반영). README 갱신, 커밋+푸시.

4. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 오늘도 오류 없이 깔끔하게 완주:
   - **4-1.** Step 1: `brew install helm` 설치 확인 (v4.2.4)
   - **4-2.** Step 2~5: Chart 뼈대 + 템플릿 9개 파일(postgres 5개, adminer 3개, Ingress 1개) 전부 정확하게 작성
   - **4-3.** Step 6: `helm lint`/`helm template`로 렌더링 결과 사전 검증, 문제 없음
   - **4-4. (핵심)** Step 7: `helm install ... --create-namespace`로 새 Namespace에 전체 스택 한 번에 배포, `curl http://localhost/helm/` → 200 확인
   - **4-5. (핵심)** Step 8: `helm upgrade --set adminer.replicas=2`로 템플릿 안 건드리고 값만으로 재배포 성공
   - **4-6. (핵심)** Step 9: `helm rollback webapp-release 1`로 리비전 되돌리기 성공
   - **4-7.** Step 10: `helm uninstall` + `kubectl delete namespace`로 전체 정리, 기존 `webapp` 프로젝트는 전혀 영향 없는 것 확인

5. **완주 기록 저장** — `notes/14/practice-selfdone.md` 작성.

## 배운 개념: Helm
`notes/concepts.md`에 정리됨. 요약: Chart(템플릿+기본값 패키지) + Values(설정값) → Release(설치 인스턴스). `helm install`/`upgrade`/`rollback`/`uninstall`로 여러 리소스를 하나의 단위로 관리. `kubectl rollout undo`가 Deployment 하나만 롤백했다면 `helm rollback`은 Chart 전체를 롤백.

## 현재 상태 (2026-09-07 기준)
- 클러스터: 기존 `webapp` Namespace(StatefulSet postgres, adminer 4개, Ingress) 그대로 유지. 이번 실습용 `webapp-helm` Namespace는 정리 완료.
- 새 디렉토리: `helm/webapp-chart/` — Chart.yaml, values.yaml, templates/ 9개 파일. 재사용 가능한 형태로 레포에 계속 보존됨 (다음에 다시 `helm install`만 하면 언제든 재배포 가능).
- GitHub 레포: `main` 브랜치에 오늘 작업(개념, 가이드, Chart 파일, 완주 기록) 전부 커밋/푸시 완료 예정

## 다음에 이어서 할 만한 것 (방향 미정, 다음에 상의 필요)
- [ ] 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s부터, kubeadm 멀티노드 구축
- [ ] 더 심화된 주제 (NetworkPolicy, CI/CD 연동, 모니터링/로깅 스택 등)
- [ ] webapp 프로젝트 추가 확장 (adminer 롤링 업데이트 재현 등)
