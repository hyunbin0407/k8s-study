# 2026-08-28 세션 요약 (5회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/04/session-summary.md](../04/session-summary.md))

## 오늘 한 일 순서

1. **"공부 순서 보여줘" 요청** — 1~4회차 완료 내역과 다음 순서(Secret → Namespace → Volume → Ingress, 클러스터 직접 구성은 보류)를 표로 정리해서 안내.

2. **"Secret부터 이어서 진행하자" 요청** — Secret 개념 설명 (ConfigMap과의 차이, base64는 암호화가 아니라는 점, `stringData`/`data`, 타입).

3. **"정리하고 실습가이드 만들어줘" 요청** — `notes/concepts.md`에 Secret 섹션 추가, `notes/05/practice-guide.md` 작성, README에 5회차 행 추가, 커밋+푸시.

4. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **4-1.** 준비 단계에서 Pod가 `ImagePullBackOff`로 걸림 → `describe`로 Docker Desktop 내부 레지스트리 미러의 500 에러가 원인임을 확인, Docker Desktop 재시작으로 해결
   - **4-2.** Step 1: Secret(`stringData`로 `DB_PASSWORD`, `API_KEY`) 작성 및 apply 성공
   - **4-3. (사이드 트랙)** "왜 03-configmap 다음이 05-secret이냐" 질문 → 제가 회차 번호와 파일 순번을 헷갈려서 04를 건너뛴 실수였음을 확인, `05-nginx-secret.yaml` → `04-nginx-secret.yaml`로 정정. 이 과정에서 `03-nginx-configmap.yaml`과 최신 `01-nginx-deployment.yaml`이 그동안 git에 커밋된 적 없었다는 것도 발견해 같이 커밋
   - **4-4.** Step 2: `get secret -o yaml`로 base64 저장 확인, `base64 -d`로 직접 디코딩해 원문 복원 → 암호화가 아니라 인코딩일 뿐이라는 것 체감. 디코딩 결과가 터미널에 예상과 다른 줄 순서로 보여서 질문 → `base64 -d` 출력에 줄바꿈이 없어서 다음 프롬프트와 같은 줄에 붙어 보인 것뿐, 정상이라고 설명
   - **4-5.** Step 3: Deployment에 `secretRef` 추가 중 `kubectl apply`가 YAML 탭 문자 에러로 실패 → nano 자동 들여쓰기가 원인, 탭을 스페이스로 수정하고 `--dry-run=client`로 검증 후 재적용해서 해결
   - **4-6.** Step 4: `kubectl exec ... env`로 컨테이너 안에서 Secret 값이 평문으로 주입되는 것 확인
   - **4-7.** Step 5: `kubectl describe deployment`에서는 Secret 이름만 보이고 값은 노출 안 되는 것 확인
   - **4-8.** Step 6: `kubectl delete -f`로 전부 정리

5. **완주 기록 저장** — `notes/05/practice-selfdone.md` 작성.

## 배운 개념: Secret
`notes/concepts.md`에 정리됨. 요약: ConfigMap과 주입 방식은 같지만 base64로 저장되고 조회 명령에서 값이 노출되지 않음. base64는 암호화가 아니므로 진짜 민감정보 보호는 RBAC나 외부 도구(Vault 등)가 담당.

## 트러블슈팅 경험 (다시 겪을 수 있으니 참고)
- Docker Desktop 내부 이미지 레지스트리 미러가 일시적으로 500 에러를 낼 수 있음 → `docker pull`로 직접 당겨봐서 문제가 인터넷/레지스트리인지 Docker Desktop 내부인지 구분, Docker Desktop 재시작으로 해결
- nano에서 YAML 편집 시 자동 들여쓰기가 탭 문자를 섞어 넣을 수 있음 → `kubectl apply --dry-run=client -f <파일>`로 적용 전 사전 검증하는 습관 필요
- manifest 파일 번호는 "만든 순서" 기준 — 회차 번호와 혼동하지 않도록 주의 (04-nginx-secret.yaml로 정정한 사례)

## 현재 상태 (2026-08-28 기준)
- 클러스터: Kubernetes 활성화, 리소스는 정리되어 비어있음
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료
- manifest 파일 목록: `01-nginx-deployment.yaml`(envFrom×2/volumeMounts 포함), `02-nginx-service.yaml`, `03-nginx-configmap.yaml`, `04-nginx-secret.yaml`

## 다음에 이어서 할 만한 것
- [ ] Namespace 개념 — 리소스를 논리적으로 나누는 개념 (다음 추천 순서)
- [ ] Volume / PersistentVolume 개념 (스토리지)
- [ ] Ingress 개념
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축