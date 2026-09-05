# 실습 12 — 직접 완주! HPA (자동 스케일링)

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Step 1: `kubectl apply -f .../metrics-server/.../components.yaml`로 metrics-server 설치
   - 예상대로 `x509: cannot validate certificate ... doesn't contain any IP SANs` 에러로 Pod가 준비 안 됨 (Docker Desktop 로컬 클러스터의 흔한 인증서 문제)
2. Step 2: `kubectl patch deployment metrics-server --type=json`으로 `--kubelet-insecure-tls` 옵션 추가 → 새 Pod로 롤링 업데이트되며 정상화, `kubectl top nodes`/`kubectl top pods`로 실제 지표 수집 확인
3. Step 3: `manifests/project/08-adminer-deployment.yaml`에 `resources.requests.cpu: 20m`, `limits.cpu: 100m` 추가 → apply 시 스펙 변경으로 롤링 업데이트 발생, `kubectl top pods`로 새 Pod들의 CPU 수치 확인
4. Step 4: `manifests/project/14-adminer-hpa.yaml` 작성(`minReplicas: 1`, `maxReplicas: 6`, CPU 50%) → apply 후 처음엔 `TARGETS: <unknown>/50%`였다가 곧 `cpu: 5%/50%`로 안정화
5. Step 5 (핵심): `kubectl run load-generator`로 부하 생성 Pod 실행
   - 1차 시도에서 `$(seq 1 8)` 사용한 스크립트가 `syntax error: unexpected word (expecting "do")`로 실패 (busybox 환경에서 `seq` 관련 문제로 추정) → 고정 숫자 목록(`1 2 3 4 5 6 7 8`)으로 바꿔서 재시도, 정상 `Running`
   - HPA를 실시간 관찰(`-w`)하며 CPU 사용률이 `130%/50%`까지 치솟고, `REPLICAS`가 4 → 6(maxReplicas 상한)까지 자동으로 늘어나는 것을 직접 목격
6. Step 6: `load-generator` 삭제 → 사용률은 바로 5%로 떨어졌지만 `REPLICAS`는 곧바로 안 줄고 약 5분간 그대로 유지(안정화 대기), 이후 서서히 `minReplicas: 1`까지 감소하는 것을 확인
7. Step 7: HPA 삭제, `kubectl scale --replicas=4`로 원래 개수 복구. metrics-server는 계속 남겨둠

## 배운 것 요약
- HPA는 metrics-server가 있어야 동작하며, 로컬(Docker Desktop) 클러스터에서는 인증서 검증 문제로 `--kubelet-insecure-tls` 같은 우회 설정이 필요할 수 있음 (운영 환경에서는 함부로 쓰면 안 되는 옵션)
- CPU 기준 HPA는 컨테이너에 `resources.requests.cpu`가 반드시 설정되어 있어야 사용률(%) 계산이 가능
- 부하 생성 스크립트 작성 시 이미지에 따라 `seq` 같은 유틸리티가 기대와 다르게 동작할 수 있음 — 고정 값 나열이 더 안전한 대안이 될 수 있음
- HPA는 확장은 빠르게, 축소는 느리게(기본 5분 안정화) 하도록 설계되어 있어 트래픽이 잠깐 튀었다 가라앉아도 Pod가 계속 늘었다 줄었다 하는 스래싱을 방지함
- `kubectl scale`(3회차, 수동)과 HPA(자동)는 내부적으로 같은 방식(Deployment의 `replicas` 필드 수정)으로 동작하지만, 트리거하는 주체가 사람이냐 컨트롤러냐의 차이
