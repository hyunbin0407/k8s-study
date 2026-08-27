# 2026-08-27 세션 요약 (4회차)

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [notes/03/session-summary.md](../03/session-summary.md))

## 오늘 한 일 순서

1. **"ConfigMap 개념부터 알려줘" 요청** — 개념 설명 (설정을 이미지와 분리하는 이유, 환경변수 vs 볼륨 마운트 주입 방식, 반영 시점 차이, 민감정보는 Secret으로).

2. **"정리하고 실습할수있게 만들어줘" 요청** — `notes/concepts.md`에 ConfigMap 섹션 추가, `notes/04/practice-guide.md` 작성, README에 4회차 행 추가, 커밋+푸시.

3. **실습 진행** — 가이드를 보며 직접 실습, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **3-1.** 준비: 기존 nginx Deployment+Service 재배포
   - **3-2.** Step 1: ConfigMap 작성 시도 — 1차 시도 때 nano 저장이 안 된 채 다음 단계로 넘어가서 `configmaps "nginx-config" not found` 발견, 원인(파일 자체가 없었음) 확인 후 재시도해서 정상 생성
   - **3-3.** Step 2: Deployment에 `envFrom.configMapRef`로 ConfigMap 연결 → apply 시 이미지 변경 없이도 Pod 스펙 변경만으로 롤링 업데이트가 발생하는 것 확인
   - **3-4.** Step 3: `kubectl exec ... env`로 환경변수 실제 주입 확인 (`GREETING`, `LOG_LEVEL=debug`)
   - **3-5. (핵심 실험 1)** Step 4: ConfigMap의 `LOG_LEVEL`을 `debug→info`로 바꿔 apply해도, 같은 Pod에서는 여전히 `debug` — 환경변수는 컨테이너 시작 시점에 값이 고정된다는 것을 직접 확인
   - **3-6.** Step 5: `kubectl rollout restart deployment/nginx-deployment`로 강제 재생성 → 새 Pod에서 `LOG_LEVEL=info` 반영 확인. 스펙을 안 바꿔도 `restartedAt` annotation으로 롤링 업데이트가 트리거된다는 것도 학습
   - **3-7. (핵심 실험 2)** Step 6(선택): Deployment에 `volumeMounts`/`volumes`로 ConfigMap을 `/etc/config`에 파일로 마운트 → ConfigMap 값을 다시 바꾸고(`info→debug-v2`) **Pod 재생성 없이 1분 대기 후** `cat`으로 확인 → 파일 내용이 자동으로 갱신되는 것 확인 (환경변수 방식과의 핵심 대조)
   - **3-8.** Step 7: `kubectl delete -f`로 Deployment/Service/ConfigMap 전부 정리

4. **완주 기록 저장** — `notes/04/practice-selfdone.md` 작성.

## 배운 개념: ConfigMap
`notes/concepts.md`에 정리됨. 요약: 설정을 이미지와 분리해서 관리. 환경변수 주입(Pod 재생성 필요)과 볼륨 마운트(kubelet이 자동 동기화) 두 방식의 반영 시점이 다름. 민감정보는 Secret으로.

## 현재 상태 (2026-08-27 기준)
- 클러스터: Kubernetes 활성화, 리소스는 정리되어 비어있음
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료
- `manifests/01-nginx-deployment.yaml`에는 `envFrom`/`volumeMounts` 설정이 계속 남아있음 (다음 실습에서도 이어서 씀). `manifests/03-nginx-configmap.yaml`의 `LOG_LEVEL` 값은 실습 마지막에 `debug-v2`로 남아있음 (문제 없으나 다음에 새로 시작할 때 참고)

## 다음에 이어서 할 만한 것
- [ ] Secret 개념 — 민감정보(비밀번호, API 키)를 ConfigMap과 비슷한 구조로, 하지만 base64 인코딩 + 접근 제어와 함께 관리 (다음 추천 순서, ConfigMap 배운 직후라 자연스러운 연장)
- [ ] Namespace 개념
- [ ] Volume / PersistentVolume 개념 (스토리지)
- [ ] Ingress 개념
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축