# 실습 01 — 직접 완주 기록 (nano로 YAML 작성)

> [practice-guide.md](practice-guide.md) 가이드를 보고 실제로 손으로 진행한 기록.

## 진행 과정

1. **Deployment YAML 작성** (nano) — 처음에 마크다운 코드블록 표시(````yaml`)의 `yaml` 글자가 1번째 줄에 섞여 들어가는 실수가 있었으나, 해당 줄 삭제 후 `kubectl apply --dry-run=client`로 문법 검증 통과
2. **Service YAML 작성** (nano) — 한 번에 정확하게 작성, dry-run 검증 통과
3. **`kubectl apply -f`** 로 Deployment + Service 배포 → `created` 확인
4. **상태 확인**: `get deployment/replicaset/pods/service` — 계층 구조(Deployment → ReplicaSet → Pod 3개) 직접 확인
5. **`kubectl describe pod`**: `Controlled By: ReplicaSet/...`, Events(`Scheduled → Pulling → Pulled → Created → Started`) 확인
6. **Self-healing 테스트**: Pod 하나(`...zx5kk`) 삭제 → 12초 만에 새 Pod(`...crbbd`, 새 IP) 자동 생성, 3개 유지 확인
7. **Service 접속 테스트**: `kubectl port-forward service/nginx-service 8080:80` → 브라우저에서 `localhost:8080` 접속 → nginx 환영 페이지 정상 확인

## 배운 점 / 트러블슈팅
- `kubectl describe pod <이름>` 처럼 가이드의 `< >`는 "실제 값으로 치환" 표시이지 문법이 아님 — 꺾쇠괄호까지 그대로 입력하면 zsh에서 리다이렉션 기호로 해석되어 `parse error` 발생. 실제 값만 입력해야 함
- nano에서 마크다운 코드블록을 복사할 때 언어 표시(````yaml`)의 `yaml` 텍스트가 섞여 들어갈 수 있으니, 파일 첫 줄이 `apiVersion:`으로 시작하는지 확인하는 습관 필요
- `kubectl apply --dry-run=client -f <파일>` 로 실제 적용 전에 YAML 문법을 미리 검증할 수 있음

## 결과
Pod / Deployment / Service 3종 세트를 개념 학습 → YAML 직접 작성 → 배포 → 상태 확인 → Self-healing 확인 → 실제 접속 확인까지 전 과정을 손으로 완주함.
