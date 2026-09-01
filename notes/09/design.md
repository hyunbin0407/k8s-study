# 미니 프로젝트 설계 — PostgreSQL + Adminer (Namespace: `webapp`)

지금까지 배운 8개 개념(Namespace, ConfigMap, Secret, Deployment+Service, PV/PVC, Ingress, 스케일링, 롤링 업데이트)을 한 번에 조합해보는 실습용 미니 프로젝트. 이번 회차는 **설계만** 하고, 실제 구현(YAML 작성 + 배포)은 다음 회차에서 진행.

## 왜 이 조합인가

- `postgres`(DB) + `adminer`(브라우저로 DB를 관리하는 가벼운 웹 UI) — 둘 다 공식 이미지 그대로 써서, 별도 앱 코드를 작성하지 않고도 "진짜 DB를 가진 2-tier 앱"을 구성할 수 있음
- Adminer 화면에서 실제로 테이블을 만들고 데이터를 넣어보면서, PV(데이터 영속성)를 눈으로 확인할 수 있음

## 아키텍처

```
                    브라우저 (http://localhost/)
                              │
                    ┌─────────▼─────────┐
                    │  Ingress (nginx)    │  기존 ingress-nginx controller 재사용 (8회차에서 설치해둔 것)
                    └─────────┬─────────┘
                              │  path: /
                    ┌─────────▼─────────┐
                    │  adminer-service    │  ClusterIP
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ adminer-deployment  │  replicas: 2  (stateless → 스케일링 가능)
                    └─────────┬─────────┘
                              │ ADMINER_DEFAULT_SERVER (ConfigMap으로 주입)
                    ┌─────────▼─────────┐
                    │  postgres-service   │  ClusterIP (외부 노출 안 함)
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ postgres-deployment │  replicas: 1  (stateful → 여러 개면 데이터 꼬임)
                    │ POSTGRES_PASSWORD    │  ← Secret
                    │ POSTGRES_DB/USER     │  ← ConfigMap
                    └─────────┬─────────┘
                              │ /var/lib/postgresql/data
                    ┌─────────▼─────────┐
                    │   PVC → PV(자동)    │  ReadWriteOnce, 1Gi
                    └────────────────────┘

전부 Namespace "webapp" 안에 격리
```

## 컴포넌트별 상세

| 리소스 | 이름 | 핵심 설정 |
|---|---|---|
| Namespace | `webapp` | 프로젝트 전체를 격리 |
| ConfigMap | `postgres-config` | `POSTGRES_DB`, `POSTGRES_USER` (비밀번호 제외 — 그건 Secret) |
| Secret | `postgres-secret` | `POSTGRES_PASSWORD` (stringData로 작성) |
| Deployment | `postgres-deployment` | image: `postgres:16`, replicas: 1, PVC 마운트 |
| Service | `postgres-service` | ClusterIP, port 5432 |
| PVC | `postgres-pvc` | ReadWriteOnce, 1Gi |
| ConfigMap | `adminer-config` | `ADMINER_DEFAULT_SERVER: postgres-service` (Service 이름으로 DB 위치 지정) |
| Deployment | `adminer-deployment` | image: `adminer:latest`, replicas: 2 |
| Service | `adminer-service` | ClusterIP, port 8080 |
| Ingress | `webapp-ingress` | path `/` → adminer-service (다른 앱과 안 겹치니 경로 prefix 없이 단순하게) |

## 배운 개념이 실제로 쓰이는 지점

| 개념 | 이 프로젝트에서의 역할 |
|---|---|
| Namespace | `webapp`로 다른 실습과 완전히 격리 |
| ConfigMap | DB 이름/유저, adminer의 접속 대상 설정 |
| Secret | DB 비밀번호 (진짜 민감정보) |
| Deployment + Service | postgres, adminer 각각 |
| PVC/PV | postgres 데이터가 Pod 재시작에도 유지되는지 직접 확인 (7회차 실험 재현) |
| Ingress | adminer 웹 UI를 브라우저로 접속 가능하게 노출 (8회차에서 설치해둔 controller 재사용) |
| 스케일링 | adminer는 replicas 늘려도 안전, postgres는 1개 고정 — "왜 DB는 함부로 스케일 못 하는가"를 실습에서 직접 체감 |
| 롤링 업데이트 | 추후 adminer 이미지 버전을 올릴 때 자연스럽게 재등장 예정 |

## 파일 구조 (다음 회차에서 작성 예정)

번호 기반 `manifests/`에 계속 쌓기보다, 프로젝트 전용 폴더로 분리:
```
manifests/project/
  01-namespace.yaml
  02-postgres-configmap.yaml
  03-postgres-secret.yaml
  04-postgres-pvc.yaml
  05-postgres-deployment.yaml
  06-postgres-service.yaml
  07-adminer-configmap.yaml
  08-adminer-deployment.yaml
  09-adminer-service.yaml
  10-ingress.yaml
```

## 다음 회차에서 할 일
- [ ] 위 순서대로 YAML 작성 및 배포 (`-n webapp`)
- [ ] Adminer 웹 UI 접속(`http://localhost/`) → 로그인 → 테이블 생성 및 데이터 입력
- [ ] postgres Pod를 삭제하고 재생성해도 데이터가 남아있는지 확인 (PV 검증)
- [ ] adminer를 `kubectl scale`로 늘려보고, 여러 Pod 어디로 붙어도 같은 DB를 보는지 확인
- [ ] (선택) adminer 이미지 버전을 바꿔서 롤링 업데이트 재현
