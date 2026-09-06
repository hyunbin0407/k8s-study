# 실습 14 — 직접 완주! Helm으로 webapp 프로젝트 패키징

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Step 1: `brew install helm`으로 Helm CLI 설치, `helm version`으로 확인 (v4.2.4)
2. Step 2: `helm/webapp-chart/` 디렉토리 구조 생성, `Chart.yaml`/`values.yaml` 작성
3. Step 3~5: 기존 `manifests/project/`의 postgres·adminer·Ingress YAML을 템플릿(`{{ .Values.xxx }}`, `{{ .Release.Namespace }}`)으로 변환 — 9개 템플릿 파일 전부 오타 없이 정확하게 작성
4. Step 6: `helm lint`(문제 없음), `helm template`로 렌더링 결과 전체 미리보기 → 모든 `{{ }}` 자리가 실제 값으로 정확히 치환된 것 확인
5. Step 7 (핵심): `helm install webapp-release helm/webapp-chart --namespace webapp-helm --create-namespace` 명령 하나로 전체 스택(Pod 5개, Service 3개, Ingress) 배포 성공. `curl http://localhost/helm/` → `200 OK` 확인
6. Step 8 (핵심): `helm upgrade --set adminer.replicas=2`로 템플릿 파일 수정 없이 명령줄 값만으로 재배포 → adminer Pod 4개→2개로 정확히 반영
7. Step 9 (핵심): `helm history`로 리비전 확인 후 `helm rollback webapp-release 1`로 REVISION 1(replicas 4) 시점으로 롤백 → Pod가 다시 4개로 복구
8. Step 10: `helm uninstall`로 Chart의 모든 리소스를 한 번에 삭제, `kubectl delete namespace webapp-helm`으로 Namespace까지 정리. 기존 `webapp` 프로젝트(postgres-0, adminer 4개)는 전혀 영향받지 않은 것 확인

## 배운 것 요약
- Helm Chart는 YAML을 템플릿화(`{{ .Values.xxx }}`, `{{ .Release.Namespace }}`)해서 값과 구조를 분리 — `values.yaml`이나 `--set`으로 여러 리소스의 설정을 한 번에 바꿀 수 있음
- `helm install` 한 줄로 여러 개별 `kubectl apply`를 대체할 수 있고, `helm uninstall` 한 줄로 전체 정리도 가능
- `helm rollback`은 2회차의 `kubectl rollout undo`(Deployment 하나만 롤백)와 달리, Chart에 포함된 **모든 리소스를 하나의 단위로** 롤백함
- 완전히 새로운 Namespace에 같은 앱을 안전하게 재배포해서 실습하는 방식으로, 기존 프로젝트(살아있는 데이터)에 전혀 영향 주지 않고 마음껏 install/upgrade/rollback/uninstall을 연습할 수 있었음
- 10회차(Ingress sticky session)와 3회차(선언적 관리) 교훈이 Helm 레벨에서도 그대로 적용된다는 것을 재확인
