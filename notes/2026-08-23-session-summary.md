# 2026-08-23 세션 요약

오늘 하루 동안 진행한 전체 흐름 요약. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.

## 환경 세팅
- Docker Desktop 설치 (macOS, Apple Silicon)
- Docker Desktop 내장 Kubernetes 활성화 (Settings → Kubernetes → Enable Kubernetes)
- GitHub 학습 기록용 레포 생성: **https://github.com/hyunbin0407/k8s-study**
  - `notes/` — 개념 정리, 실습 기록
  - `manifests/` — 실습에 쓴 YAML 파일

## 학습 방식 (중요 — 이후에도 이 방식 유지)
- **개념 먼저 배우고, 그다음 손으로 직접 실습**하는 순서 선호
- 실습은 Claude가 대신 실행하는 게 아니라 **본인이 직접 `kubectl`/에디터로 타이핑**하며 진행하길 원함
  → Claude는 가이드 제공 + 결과 검증(확인)만 담당, 실행은 사용자가 함
  → 에디터는 `nano` 사용 중
- 개념/실습 내용은 매번 `notes/concepts.md`, `notes/*.md`에 정리 후 커밋+푸시하는 루틴

## 배운 개념 (현재 `notes/concepts.md`에 정리됨)
1. **쿠버네티스란** — 컨테이너 오케스트레이션, 자동 배포/복구/스케일링/로드밸런싱
2. **컨테이너란** — VM과의 차이, Docker와의 관계, 이미지 vs 컨테이너
3. **Pod란** — 배포 최소 단위, 불변/일회용, 그래서 Deployment로 감싸서 씀
4. **Deployment란** — Pod를 desired state로 유지 (Deployment → ReplicaSet → Pod 계층)
5. **Service란** — Pod IP가 바뀌어도 고정 접속점 제공, Label Selector로 라우팅

> 참고: "클라우드 매니지드 K8s(GKE/EKS/AKS)"와 "클러스터 직접 구성 도구(kubeadm/kubespray)"는
> 한 번 설명했다가 **사용자 요청으로 `concepts.md`에서 삭제함** (2026-08-23). 필요하면 다시 설명 가능.

## 완료한 실습 — 실습 01: Deployment + Service로 nginx 배포
- 관련 파일: [practice-01-guide.md](practice-01-guide.md) (가이드), [2026-08-23-practice-01-selfdone.md](2026-08-23-practice-01-selfdone.md) (직접 완주 기록)
- Deployment YAML(`manifests/01-nginx-deployment.yaml`), Service YAML(`manifests/02-nginx-service.yaml`)을 nano로 직접 작성
- `kubectl apply` → 3개 Pod 정상 배포 확인 (`get deployment/replicaset/pods/service`)
- `kubectl describe pod`, `kubectl logs`로 상세 정보 확인
- Pod 강제 삭제 → **Self-healing 직접 목격** (수 초 만에 새 Pod 자동 생성, 3개 유지)
- `kubectl port-forward`로 Service 접속 → 브라우저에서 nginx 환영 페이지 확인 성공
- 실습 후 `kubectl delete -f`로 리소스 정리 완료 (현재 클러스터는 비어있는 상태)

## 트러블슈팅 경험 (다시 겪을 수 있으니 참고)
- nano로 마크다운 코드블록 복사 시, 코드펜스 언어 표시(````yaml`)의 `yaml` 글자만 파일에 섞여 들어가는 실수 → 첫 줄이 `apiVersion:`으로 시작하는지 확인하는 습관 필요
- 가이드 문서의 `<Pod 이름>` 같은 꺾쇠괄호는 "실제 값으로 치환"하라는 표시일 뿐, 그대로 입력하면 zsh에서 리다이렉션으로 해석되어 에러(`parse error`) 발생
- `kubectl apply --dry-run=client -f <파일>` 로 실제 적용 전에 YAML 문법 사전 검증 가능

## 현재 상태 (2026-08-23 기준)
- 클러스터: Kubernetes 활성화되어 있음, 리소스는 정리되어 비어있음
- GitHub 레포: `main` 브랜치에 위 내용 전부 커밋/푸시 완료

## 다음에 이어서 할 만한 것
- [ ] 롤링 업데이트 실습 (이미지 버전 변경 → 무중단 배포 확인)
- [ ] 스케일링 실습 (`kubectl scale`로 Pod 개수 조절)
- [ ] ConfigMap / Secret 개념 — 설정값을 코드와 분리하기
- [ ] Namespace 개념
- [ ] Volume / PersistentVolume 개념 (스토리지)
- [ ] Ingress 개념 (Service보다 상위의 외부 노출 방식)