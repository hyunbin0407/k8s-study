# 2026-09-05 세션 요약 (12회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/11/session-summary.md](../11/session-summary.md))

## 오늘 한 일 순서

1. **"다음꺼 하자" 요청** — 지난 회차에 정해둔 순서대로 HPA(자동 스케일링) 개념 설명 (수동 스케일링과의 관계, metrics-server 필요성, `resources.requests.cpu` 필수인 이유).

2. **"정리해주고 실습가이드 만들어줘" 요청** — `notes/concepts.md`에 HPA 섹션 추가, `notes/12/practice-guide.md` 작성(metrics-server 설치 → adminer에 CPU requests 추가 → HPA 생성 → 부하 생성으로 자동 확장 확인 → 축소 확인), README 갱신, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **3-1.** Step 1: metrics-server 설치 → 예상대로 노드 인증서 검증 실패(`x509: ... doesn't contain any IP SANs`)로 준비 안 됨
   - **3-2.** Step 2: `--kubelet-insecure-tls` 패치로 해결, `kubectl top nodes`/`kubectl top pods` 정상 작동 확인
   - **3-3.** Step 3: adminer Deployment에 `resources.requests.cpu: 20m` 추가 → 롤링 업데이트로 새 Pod 교체, 지표 수집 확인
   - **3-4.** Step 4: HPA 생성 → `<unknown>` 거쳐 `cpu: 5%/50%`로 안정화
   - **3-5. (핵심)** Step 5: `busybox` 부하 생성 Pod 실행 — 1차 시도에서 `seq` 관련 쉘 스크립트 문법 오류 발생, 고정 숫자 나열로 수정해 재시도 성공. HPA를 실시간 관찰하며 사용률이 `130%`까지 치솟고 `REPLICAS`가 4→6(최대치)으로 자동 확장되는 것을 직접 목격
   - **3-6.** Step 6: 부하 제거 후 사용률은 즉시 낮아졌지만 `REPLICAS`는 약 5분간 그대로 유지(안정화 대기)되다가 서서히 `minReplicas: 1`까지 감소하는 것 확인
   - **3-7.** Step 7: HPA 삭제, `kubectl scale --replicas=4`로 원상 복구 (경로 착오로 `cd` 안 하고 명령어 실행해 에러 났던 것도 안내해서 해결)

4. **완주 기록 저장** — `notes/12/practice-selfdone.md` 작성.

## 배운 개념: HPA (Horizontal Pod Autoscaler)
`notes/concepts.md`에 정리됨. 요약: 3회차 수동 스케일링의 자동화 버전. metrics-server가 CPU/메모리 지표를 수집하고, HPA 컨트롤러가 주기적으로 확인해 Deployment의 replicas를 자동 조정. CPU 기준 스케일링엔 `resources.requests.cpu` 설정이 필수. 확장은 빠르게, 축소는 느리게(기본 5분 안정화) 동작해 스래싱 방지.

## 현재 상태 (2026-09-05 기준)
- 클러스터: `webapp` Namespace 전체(StatefulSet postgres, adminer 4개, Ingress) 살아있는 상태로 유지. HPA는 실습 종료 후 삭제, adminer는 4개로 복구됨.
- `metrics-server`는 `kube-system`에 계속 설치된 채로 남겨둠 (다른 실습에서도 유용).
- GitHub 레포: `main` 브랜치에 오늘 작업(개념, 가이드, manifest, 완주 기록) 전부 커밋/푸시 완료 예정

## 다음에 이어서 할 만한 것
- [ ] RBAC (권한 관리) — 심화 학습 마지막 순서
- [ ] (선택) adminer 이미지 버전 변경으로 롤링 업데이트 재현
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s부터, kubeadm 멀티노드 구축
