# 실습 15 — 직접 완주! Prometheus + Grafana 모니터링 스택

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. Step 1: `helm repo add prometheus-community` + `helm repo update` → `kube-prometheus-stack` Chart 검색 성공 (처음으로 남이 만든 공식 Chart 사용)
2. Step 2: `helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace` → 예상보다 빠르게(약 2분) 6개 컴포넌트(alertmanager, grafana, kube-prometheus-operator, kube-state-metrics, node-exporter, prometheus) 전부 `Running`
3. Step 3: `kubectl get secret ... admin-password | base64 -d`로 Grafana 관리자 비밀번호 확인
4. Step 4: `kubectl port-forward svc/monitoring-grafana 3000:80`로 접속 시도
   - "이메일 또는 사용자 이름" 입력창을 보고 구글 로그인으로 착각 → Grafana 자체 로컬 계정이라고 안내
   - 비밀번호를 정확히 복사했는데도 `Invalid username or password` 발생 → 서버 쪽 로그/시크릿/env var 전부 확인해도 이상 없어 원인 특정 실패, `grafana cli admin reset-admin-password`로 비밀번호를 확실한 값으로 강제 초기화해서 해결
   - 이후 대시보드에서 갑자기 "No data" 발생 → 서버(HPA/Pod/모니터링 스택)는 전부 정상, `kubectl port-forward`가 끊긴 것이 원인으로 추정 → 재실행해서 해결
5. Step 5: `Kubernetes / Compute Resources / Namespace (Pods)` 대시보드에서 `namespace=webapp` 선택, 기준선(baseline) 그래프 확인
6. Step 6: 12회차의 HPA(`manifests/project/14-adminer-hpa.yaml`) 재적용
7. Step 7 (핵심): `busybox` 부하 생성 시도
   - 1차: 여러 줄로 나눈 명령어를 복사/붙여넣기 하다가 `StartError`(`exec: " ": executable file not found`) 발생 — 명령어가 깨져서 전달된 것으로 추정
   - 2차: 한 줄 명령어로 재시도했으나 이번엔 `Error`(`syntax error: unexpected newline`) — 터미널에서 긴 한 줄이 표시상 줄바꿈되며 실제로 개행이 섞여 들어간 것으로 추정
   - 3차 (해결): 인라인 명령어 대신 YAML 파일(`/tmp/load-generator.yaml`)로 작성 — nano로 만들다 또 들여쓰기 문제(YAML 파싱 에러)가 나서 Claude가 파일을 직접 작성해 최종 해결. 이후 정상 `Running`
   - CPU 사용률이 `500%/50%`까지 치솟고 `REPLICAS`가 자동으로 최대치(6)까지 늘어나는 것을 **Grafana 그래프**와 **`kubectl get hpa`** 양쪽에서 동시에 확인
8. Step 8: 부하 제거 → CPU 사용률이 즉시 안 떨어지고 잠시 높게 유지되다가(측정 지연), 이후 그래프도 점차 하락, HPA도 `REPLICAS: 1`(최소치)까지 자동 축소되는 것 확인
9. Step 9: HPA 삭제, adminer `replicas: 4`로 복구, port-forward 종료. 모니터링 스택은 요청대로 유지

## 배운 것 요약
- Prometheus/Grafana는 metrics-server(순간 스냅샷)와 달리 시계열로 지표를 쌓아 장기 추이·대시보드·알림에 활용 가능
- Helm으로 커뮤니티 공식 Chart(`kube-prometheus-stack`)를 설치하는 경험 — 우리가 만든 Chart와 달리 여러 컴포넌트를 한 번에 통합 설치해줌
- Grafana 관리자 비밀번호가 예상과 다르게 인증 실패할 때, `grafana cli admin reset-admin-password`로 강제 초기화하는 복구 방법 실전 사용
- `kubectl port-forward`는 오래 켜두면 연결이 끊길 수 있음 — 대시보드에 갑자기 "No data"가 뜨면 서버보다 클라이언트 연결(포트포워드) 문제부터 의심
- 긴 인라인 셸 명령어는 터미널 줄바꿈/복사 과정에서 깨지기 쉬움 — 반복되는 문제라면 YAML 파일로 작성해 `kubectl apply -f`하는 방식이 더 안정적
- HPA의 스케일 업/다운을 실시간 그래프(Grafana)와 텍스트(kubectl) 양쪽에서 동시에 관찰하며, 지표 측정에는 약간의 지연(래깅)이 있다는 것도 실전에서 체감
