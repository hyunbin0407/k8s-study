# 2026-09-06 세션 요약 (13회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/12/session-summary.md](../12/session-summary.md))

## 오늘 한 일 순서

1. **"RBAC 하자" 요청** — 개념 설명 (Role/ClusterRole/RoleBinding/ClusterRoleBinding 4종, ServiceAccount, 최소 권한 원칙, 지금까지 아무 제약 없이 쓸 수 있었던 이유).

2. **"정리하고 실습가이드 만들어줘" 요청** — `notes/concepts.md`에 RBAC 섹션 추가, `notes/13/practice-guide.md` 작성(ServiceAccount → Role → RoleBinding → 권한 확인 → 실제 API 호출로 조회/삭제 시도), README 갱신, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 순조롭게 진행 (오늘은 오류 없이 깔끔하게 완주):
   - **3-1.** Step 1~3: `readonly-sa` ServiceAccount, `pod-reader` Role(get/list/watch만), `read-pods-binding` RoleBinding 생성
   - **3-2.** Step 4: `kubectl auth can-i --as=...`로 `readonly-sa`는 조회 가능/삭제 불가, `default` SA는 아무 권한 없음을 확인
   - **3-3.** Step 5~6: `readonly-sa`를 쓰는 실제 Pod(`rbac-test-pod`)를 띄워서, 마운트된 토큰으로 쿠버네티스 API에 직접 GET 요청 → `200 OK` 확인
   - **3-4. (핵심)** Step 7: 같은 방식으로 `postgres-0`에 DELETE 요청 → `403 Forbidden` 응답 확인, 실제로 안 지워진 것 재확인
   - **3-5.** Step 8: 사용자가 스스로 진행 — 본인의 `kubectl`(cluster-admin)로는 `delete pods`/`delete namespaces` 둘 다 `yes`인 것 확인
   - **3-6.** Step 9: "네가 마무리해줘" 요청으로 Claude가 정리 대행 (rbac-test-pod, RoleBinding, Role, ServiceAccount 삭제, webapp 원래 리소스는 영향 없음 확인)

4. **완주 기록 저장** — `notes/13/practice-selfdone.md` 작성.

## 배운 개념: RBAC
`notes/concepts.md`에 정리됨. 요약: Role(권한 목록)+RoleBinding(부여)=실제 권한. 기본적으로 전부 거부, 명시한 것만 허용. ServiceAccount로 Pod(앱)를 식별. `kubectl auth can-i`로 빠른 검증 가능.

## 🎉 마일스톤: 심화 학습 3종 완료
9~13회차로 이어온 "심화 학습" 트랙(StatefulSet → HPA → RBAC)이 이번 회차로 전부 완료됨. 핵심 커리큘럼(1~8회차) + 미니 프로젝트(9~10회차) + 심화 학습(11~13회차)까지, 계획했던 학습 로드맵이 여기서 일단락됨.

## 현재 상태 (2026-09-06 기준)
- 클러스터: `webapp` Namespace 전체(StatefulSet postgres, adminer 4개, Ingress) 살아있는 상태로 유지. RBAC 실습 리소스는 정리 완료.
- GitHub 레포: `main` 브랜치에 오늘 작업(개념, 가이드, manifest, 완주 기록) 전부 커밋/푸시 완료 예정

## 다음에 이어서 할 만한 것 (방향 미정, 다음에 상의 필요)
- [ ] 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s부터, kubeadm 멀티노드 구축 (예전부터 보류해둔 주제, 지금까지 쌓은 기본기로 재도전할 만한 시점일 수 있음)
- [ ] 더 심화된 주제 (NetworkPolicy, Helm, CI/CD 연동, 모니터링/로깅 스택 등)
- [ ] webapp 프로젝트 추가 확장 (adminer 롤링 업데이트 재현 등 미완료 항목)
