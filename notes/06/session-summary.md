# 2026-08-29 세션 요약 (6회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/05/session-summary.md](../05/session-summary.md))

## 오늘 한 일 순서

1. **"Namespace 개념부터 알려줘" 요청** — 개념 설명 (필요한 이유, `default`가 지금까지 암묵적으로 써온 Namespace였다는 것, Namespaced vs Cluster-scoped 리소스, Namespace 간 통신 방식).

2. **"정리하고 6회차 실습 가이드도 만들어줘" 요청** — `notes/concepts.md`에 Namespace 섹션 추가, `notes/06/practice-guide.md` 작성, README에 6회차 행 추가, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **3-1.** Step 1: `manifests/05-dev-namespace.yaml` 작성 → `dev` Namespace 생성 확인
   - **3-2.** Step 2: 기존 4개 manifest(Deployment/Service/ConfigMap/Secret)를 `-n dev`로 배포 → Pod 3개 Running 확인
   - **3-3.** Step 3: 완전히 같은 이름으로 `-n` 없이(=`default`) 또 배포 → 이름이 겹쳐도 충돌 없이 공존하는 것 확인, `-A`로 두 Namespace의 Pod가 `NAMESPACE` 컬럼으로만 구분되는 것 확인
   - **3-4.** Step 4: `kubectl get deployment` / `-n dev` / `-A` 비교 → `-n` 미지정 시 항상 `default`가 기본값임을 확인
   - **3-5. (핵심 실험)** Step 5: `default`의 Pod에서 `curl http://nginx-service`(자기 Namespace로 연결) vs `curl http://nginx-service.dev.svc.cluster.local`(전체 DNS로 dev에 연결) 둘 다 성공 → 짧은 이름은 자기 Namespace 안에서만 찾는다는 것을 직접 확인
   - **3-6.** Step 6: `kubectl delete namespace dev`로 dev 안의 모든 리소스를 한 번에 정리, `default`는 개별 delete로 정리

4. **완주 기록 저장** — `notes/06/practice-selfdone.md` 작성.

## 배운 개념: Namespace
`notes/concepts.md`에 정리됨. 요약: 클러스터를 논리적으로 나누는 격리 단위. 같은 이름의 리소스도 Namespace가 다르면 별개 취급. `-n` 미지정 시 기본값은 `default`. Namespace 간 통신은 전체 DNS 이름(`<서비스>.<네임스페이스>.svc.cluster.local`) 필요. Namespace 삭제 시 안의 모든 리소스가 함께 삭제됨.

## 현재 상태 (2026-08-29 기준)
- 클러스터: Kubernetes 활성화, 리소스는 정리되어 비어있음 (`dev` Namespace도 삭제되어 원래 상태로 복귀)
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료
- manifest 파일 목록: `01-nginx-deployment.yaml`, `02-nginx-service.yaml`, `03-nginx-configmap.yaml`, `04-nginx-secret.yaml`, `05-dev-namespace.yaml`

## 다음에 이어서 할 만한 것
- [ ] Volume / PersistentVolume 개념 — 데이터 영속성(스토리지) (다음 추천 순서)
- [ ] Ingress 개념
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축
