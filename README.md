# k8s-study

쿠버네티스 학습 기록 저장소입니다. Docker Desktop 내장 Kubernetes 클러스터로 실습하며 배운 내용을 정리합니다.

## 진행 기록


개념은 [notes/concepts.md](notes/concepts.md)에 계속 누적 정리합니다. 그 외 실습/세션 기록은 회차별 폴더로 관리합니다 — 각 폴더의 `session-summary.md`가 그 회차의 입구입니다.

| 회차 | 날짜 | 내용 | 폴더 |
| --- | --- | --- | --- |
| 10 (최신, 다음에 여기부터) | 2026-09-01 | 미니 프로젝트 구현: webapp (PostgreSQL + Adminer) | [notes/10/](notes/10/) |
| 9 | 2026-09-01 | 미니 프로젝트 설계: webapp (PostgreSQL + Adminer) | [notes/09/](notes/09/) |
| 8 | 2026-09-01 | Ingress (경로 기반 라우팅) | [notes/08/](notes/08/) |
| 7 | 2026-08-30 | Volume / PersistentVolume | [notes/07/](notes/07/) |
| 6 | 2026-08-29 | Namespace | [notes/06/](notes/06/) |
| 5 | 2026-08-28 | Secret | [notes/05/](notes/05/) |
| 4 | 2026-08-27 | ConfigMap (환경변수/볼륨 마운트) | [notes/04/](notes/04/) |
| 3 | 2026-08-26 | 스케일링 | [notes/03/](notes/03/) |
| 2 | 2026-08-24 | 롤링 업데이트 & 롤백 | [notes/02/](notes/02/) |
| 1 | 2026-08-23 | 환경 세팅, 기본 개념(Pod/Deployment/Service), nginx 배포 | [notes/01/](notes/01/) |

## 개념 사전

[notes/concepts.md](notes/concepts.md) — 쿠버네티스 개요, 컨테이너, Pod, Deployment, Service, 롤링 업데이트, 스케일링, ConfigMap, Secret, Namespace, Volume/PersistentVolume, Ingress 등 지금까지 배운 개념 전부.

## 환경

- Docker Desktop (macOS, Apple Silicon)
- Kubernetes: Docker Desktop 내장 단일 노드 클러스터
- 도구: `kubectl`