# 실습 16 — 직접 완주! GitOps (ArgoCD로 git push 자동 배포)

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Step 1: `helm repo add argo` + `helm install argocd argo/argo-cd -n argocd --create-namespace` → 약 30초 만에 7개 컴포넌트(application-controller, applicationset-controller, dex-server, notifications-controller, redis, repo-server, server) 전부 Running
2. Step 2: `argocd-initial-admin-secret`에서 관리자 비밀번호 확인 (15회차 Grafana와 동일한 패턴)
3. Step 3: `port-forward svc/argocd-server 8080:443`로 접속 → 자체 서명 인증서 경고(`ERR_CERT_AUTHORITY_INVALID`) 발생, 크롬의 "고급 → 안전하지 않음으로 이동"으로 우회 후 로그인 성공
4. Step 4: `manifests/argocd-webapp-application.yaml` 작성 — `repoURL`을 실제 GitHub 레포로, `path: helm/webapp-chart`, `destination.namespace: webapp-gitops`, `syncPolicy.automated.selfHeal/prune: true` 설정 → apply
5. Step 5 (핵심): `kubectl`/`helm`을 한 번도 직접 실행하지 않았는데 ArgoCD가 자동으로 `webapp-gitops` Namespace에 ConfigMap/Secret/Service/StatefulSet/Deployment/Ingress 전체를 배포 — `SYNC STATUS: Synced`, `HEALTH STATUS: Healthy` 확인
6. Step 6 (핵심): `helm/webapp-chart/values.yaml`의 `adminer.replicas`를 4→2로 수정 후 git commit + push만 실행 → **`kubectl`/`helm` 명령 없이** 몇 분(실제로는 예상보다 훨씬 빨리) 안에 Pod가 4개→2개로 자동 반영되는 것 확인
7. Step 7 (핵심): `kubectl scale --replicas=5`로 수동 변경 시도 → 잠깐 5개로 늘었다가 곧바로 ArgoCD의 self-heal이 Git 상태(2개)로 자동 되돌리는 것 확인 (`Application` 상태: `successfully synced (all tasks run)`)
8. Step 8: Claude가 대행 — Application/Namespace(`webapp-gitops`) 삭제, `values.yaml`을 다시 4로 되돌려 커밋+푸시. ArgoCD 자체와 기존 `webapp`/`monitoring` 프로젝트는 유지

## 배운 것 요약
- GitOps는 Git을 "원하는 상태의 유일한 기준"으로 삼고, 클러스터 내부 에이전트(ArgoCD)가 이를 Pull 방식으로 따라감 — 전통적 Push 기반 CI/CD와 달리 클러스터가 외부에 노출될 필요가 없어 로컬 클러스터에도 적용 가능
- `Application`이라는 CRD로 "어느 Git 레포의 어느 경로를 감시할지" 선언적으로 정의
- `git push`만으로 실제 클러스터가 바뀌는 것을 직접 목격 — `kubectl`/`helm`은 이제 "직접 실행"이 아니라 "Git에 반영"하는 방식으로 완전히 대체 가능함을 체감
- `selfHeal: true`가 만드는 강력한 효과: `kubectl scale` 같은 수동 조작도 결국 Git 상태로 자동 복구됨 — 3회차에서 배운 선언적 관리의 가장 극단적인 형태
- 자체 서명 인증서로 인한 브라우저 경고는 로컬 개발 도구에서 흔히 발생하며, 신뢰할 수 있는 로컬 환경이면 우회해도 무방
