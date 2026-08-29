# 실습 06 — 직접 완주! Namespace

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. 준비 단계: `kubectl get pods -A | grep nginx`로 클러스터가 깨끗한 상태인지 확인
2. `manifests/05-dev-namespace.yaml` 작성(`kind: Namespace`, `name: dev`) → apply, `kubectl get namespace`로 `dev`가 추가된 것 확인
3. 기존 4개 manifest(Deployment/Service/ConfigMap/Secret)를 `-n dev` 옵션으로 `dev` Namespace에 배포 → Pod 3개 `ContainerCreating → Running` 전환 확인
4. **같은 이름**으로 `-n` 옵션 없이(=`default`) 4개 manifest를 또 배포 → 이름이 완전히 겹치는데도 에러 없이 정상 생성됨을 확인
5. `kubectl get pods -A -l app=nginx`로 `default`와 `dev` 양쪽에 동일한 이름의 Pod들이 `NAMESPACE` 컬럼으로만 구분되어 공존하는 것 확인 (두 Deployment의 ReplicaSet 해시 접미사까지 동일했음 — 완전히 같은 YAML이라 해시가 같았던 것, Namespace로만 구분됨)
6. `kubectl get deployment` (default만) / `-n dev` (dev만) / `-A` (전체, 시스템 Deployment까지) 비교 → `-n` 미지정 시 항상 `default`가 기본값이라는 것 확인
7. **핵심 실험**: `default`의 Pod 안에서
   - `curl http://nginx-service` → 짧은 이름은 **자신이 속한 Namespace(default)**의 서비스로 연결
   - `curl http://nginx-service.dev.svc.cluster.local` → 전체 DNS 이름으로 **dev**의 서비스에 별도로 연결
   - 둘 다 정상 응답(nginx 환영 페이지)이 왔지만 실제로는 서로 다른 Service/Pod 그룹에 연결된 것임을 확인
8. `kubectl delete namespace dev`로 `dev` 안의 모든 리소스(Deployment/Service/ConfigMap/Secret)를 한 번에 정리, `default`는 개별 `kubectl delete -f`로 정리

## 배운 것 요약
- Namespace는 클러스터를 논리적으로 나누는 격리 단위 — 같은 이름의 리소스도 Namespace가 다르면 완전히 별개로 취급됨
- `kubectl` 명령은 `-n` 미지정 시 항상 현재 컨텍스트의 기본 Namespace(`default`)만 대상으로 함 — 지금까지 실습에서 `-n` 없이도 잘 됐던 이유
- Namespace 간 통신: 짧은 서비스 이름은 자기 Namespace 안에서만 찾고, 다른 Namespace의 리소스는 `<이름>.<네임스페이스>.svc.cluster.local` 형식의 전체 DNS 이름이 필요
- Namespace를 삭제하면 그 안의 모든 리소스가 함께 삭제됨 (편리하지만 실무에서는 신중하게 사용해야 할 부분)
