# 2026-08-23 — Docker Desktop 설치 & 시작

## 한 일
- Docker Desktop 설치 완료 (macOS, Apple Silicon)
- GitHub 학습 기록용 저장소(`k8s-study`) 생성

- Docker Desktop에서 Kubernetes 활성화 완료
- `kubectl get nodes` 확인 → `docker-desktop` 컨텍스트, `desktop-control-plane` 노드 `Ready` (v1.36.1)
- 시스템 파드(coredns, etcd, apiserver, scheduler 등) 전부 `Running` 확인

## 다음 할 일
- 쿠버네티스 핵심 개념 학습 시작 (실습 전 개념 정리 우선)
- 이후 `kubectl`로 첫 리소스 배포해보기