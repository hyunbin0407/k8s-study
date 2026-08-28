# 실습 05 — 직접 완주! Secret

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. 준비 단계에서 Deployment+Service+ConfigMap 재배포 시도 중 Pod가 전부 `ImagePullBackOff`로 걸림
   - `kubectl describe pod`로 원인 확인: Docker Desktop 내부 이미지 레지스트리 미러(`registry-mirror`)가 500 에러를 내며 이미지를 못 받아오는 상태
   - `docker pull nginx:latest`는 정상 작동해 인터넷/레지스트리 자체는 문제없음을 확인, Docker Desktop 자체 재시작으로 해결 (재시작 후 kubelet이 자동 재시도해서 Pod 정상화)
2. `manifests/04-nginx-secret.yaml` 작성(`stringData`로 `DB_PASSWORD`, `API_KEY` 평문 입력) → apply로 Secret 생성
   - (사이드 트랙) 원래 가이드에 파일명이 `05-nginx-secret.yaml`로 잘못 안내되어 있던 걸 발견 — ConfigMap이 `03-`이니 Secret은 `04-`가 맞다는 논리로 `04-nginx-secret.yaml`로 정정. 이 과정에서 `03-nginx-configmap.yaml`과 최신 `01-nginx-deployment.yaml`(envFrom/volumeMounts 포함)이 그동안 git에 커밋된 적이 없었다는 것도 발견해 같이 커밋
3. `kubectl get secret -o yaml`로 값이 base64로 저장된 것 확인, `base64 -d`로 직접 디코딩해서 원문(`password123`) 복원 → base64는 암호화가 아니라 인코딩일 뿐이라는 것을 실습으로 체감
4. `manifests/01-nginx-deployment.yaml`의 `envFrom`에 `secretRef` 추가 시도 중 `kubectl apply`가 YAML 파싱 에러(`found a tab character that violates indentation`)로 실패
   - nano 자동 들여쓰기 때문에 스페이스 대신 탭이 섞여 들어간 게 원인. 탭을 스페이스로 수정 후 `--dry-run=client`로 사전 검증하고 재적용 → 정상 롤링 업데이트 확인
5. `kubectl exec ... env`로 컨테이너 안에서 Secret 값이 **평문 그대로** 주입되는 것 확인 (ConfigMap과 사용법 동일)
6. `kubectl describe deployment`로는 `nginx-secret`이라는 **이름만** 보이고 실제 값(`DB_PASSWORD`, `API_KEY`)은 노출되지 않는 것 확인 — ConfigMap과의 실질적 차이 체감
7. `kubectl delete -f`로 Deployment/Service/ConfigMap/Secret 전부 정리 완료

## 배운 것 요약
- Secret은 ConfigMap과 Pod 주입 방식(환경변수/볼륨)이 동일하지만, base64로 저장되고 `describe`/일반 조회에서 값이 노출되지 않는다는 점이 다름
- base64는 암호화가 아니라 인코딩 — `base64 -d` 한 줄이면 누구나 원문 복원 가능. 진짜 보안은 접근 제어(RBAC)나 외부 secret 관리 도구가 담당
- YAML 들여쓰기에 탭이 섞이면 파싱 에러 발생 — `kubectl apply --dry-run=client`로 사전 검증하는 습관이 실전에서 유용함을 재확인
- 인프라(Docker Desktop) 자체의 일시적 장애(이미지 미러 500 에러)와 YAML 문법 에러를 구분해서 진단하는 경험 — 에러 메시지와 `describe`의 Events를 먼저 확인하는 게 원인 파악의 출발점