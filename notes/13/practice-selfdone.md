# 실습 13 — 직접 완주! RBAC

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Step 1: 제한된 권한을 가질 `ServiceAccount`(`readonly-sa`) 생성, 기존 `default` SA와 나란히 존재하는 것 확인
2. Step 2: `Role`(`pod-reader`) 작성 — `pods`에 대해 `get`/`list`/`watch`만 허용
3. Step 3: `RoleBinding`(`read-pods-binding`)으로 `readonly-sa`에 `pod-reader` Role 실제 연결
4. Step 4: `kubectl auth can-i --as=...`로 빠른 권한 확인
   - `readonly-sa`: `list pods` → `yes`, `delete pods` → `no`
   - `default` SA(아무 Role도 없음): `list pods` → `no`
5. Step 5: `readonly-sa`를 쓰는 실제 Pod(`rbac-test-pod`, `curlimages/curl`) 배포
6. Step 6: Pod 안에서 마운트된 토큰으로 쿠버네티스 API에 직접 GET 요청 → `HTTP 200`, Pod 목록 조회 성공 확인
7. Step 7 (핵심): 같은 방식으로 `postgres-0`에 DELETE 요청 시도 → `403 Forbidden` 응답 (`"cannot delete resource \"pods\""`) 확인, `postgres-0`이 실제로 안 지워지고 멀쩡한 것 재확인
8. Step 8: 본인의 실제 `kubectl`(cluster-admin)로는 `delete pods`, `delete namespaces` 둘 다 `yes`인 것 확인 — 지금까지 아무 제약 없이 실습할 수 있었던 이유를 명확히 확인
9. Step 9: RBAC 실습에서 만든 리소스(rbac-test-pod, RoleBinding, Role, ServiceAccount) 전부 정리 (Claude가 대행)

## 배운 것 요약
- RBAC은 "기본적으로 전부 거부, 명시한 것만 허용"하는 방식 — Role에 없는 동작은 자동으로 거부됨
- Role만 만들고 RoleBinding으로 연결 안 하면 아무 효과가 없음 (권한 목록과 부여는 별개의 단계)
- `kubectl auth can-i --as=<ServiceAccount>`로 실제 Pod 없이도 권한을 빠르게 예측/검증 가능
- Pod 안에는 자신의 ServiceAccount 토큰이 자동으로 마운트되어 있고, 이걸로 쿠버네티스 API 서버에 직접 HTTP 요청을 보내는 게 실제로 앱이 클러스터와 통신하는 방식
- 권한이 없는 API 요청은 `403 Forbidden`으로 명확하게 거부되며, 거부된 요청은 실제로 아무 부작용도 남기지 않음
- 지금까지 실습 전체가 아무 문제 없이 진행될 수 있었던 건 처음부터 `cluster-admin` 권한으로 작업해왔기 때문 — 실무에서는 이런 무제한 권한을 아무한테나 주지 않음
