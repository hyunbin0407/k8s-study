# 쿠버네티스 개념 정리

질문하고 답변받은 개념들을 여기에 계속 정리합니다.

<!-- 아래에 개념이 하나씩 추가됩니다 -->

## 쿠버네티스란?

컨테이너로 실행되는 애플리케이션을 자동으로 **배포·확장·관리**해주는 컨테이너 오케스트레이션 도구.

- Docker: 컨테이너 하나를 어떻게 포장/실행할지 다룸
- Kubernetes: 그 컨테이너들을 어느 서버에, 몇 개나, 어떻게 계속 살아있게 운영할지 지휘

### 핵심 기능
- **자동 배포/롤아웃**: 원하는 상태(desired state)를 선언하면 알아서 실행
- **자동 복구(Self-healing)**: 컨테이너가 죽으면 자동 재시작/재배치
- **오토스케일링**: 트래픽에 따라 컨테이너 개수 자동 조절
- **로드밸런싱**: 여러 컨테이너에 트래픽 분산
- **롤링 업데이트/롤백**: 무중단 배포, 문제 시 자동 복귀
- **멀티 노드 관리**: 여러 서버(노드)를 하나의 클러스터로 묶어 관리

### 내 환경과의 연결
Docker Desktop에서 켠 Kubernetes = 로컬 PC 한 대를 "1노드짜리 미니 클러스터"로 만든 것. 실무에서는 노드가 수십~수백 대지만 개념 학습엔 1노드로 충분.

## 컨테이너란?

애플리케이션 코드 + 실행에 필요한 모든 것(라이브러리, 설정, 환경)을 하나로 묶어, 어디서든 동일하게 실행되게 만든 **격리된 실행 단위**.

- 해결하는 문제: "내 컴퓨터에서는 되는데요" — 환경 차이로 인한 오동작 방지. 실행 환경 자체를 코드와 함께 패키징.

### VM vs 컨테이너
| | VM | 컨테이너 |
|---|---|---|
| 격리 단위 | OS 전체를 통째로 복제 (하드웨어 가상화) | OS 커널 공유, 프로세스만 격리 |
| 무게 | 무겁다 (GB, 부팅 수십 초~분) | 가볍다 (MB, 시작 1초 내외) |
| 밀도 | 서버당 소수 | 서버당 수백 개 가능 |

리눅스 커널의 **namespace**(격리) + **cgroup**(자원 제한)으로 구현. OS를 복제하지 않고도 독립된 환경처럼 보이게 만듦.

### Docker와의 관계
- 컨테이너: 개념/기술 (표준 규격 = OCI)
- Docker: 컨테이너를 빌드(build)·배포(push/pull)·실행(run)하게 해주는 대표 도구

### 이미지 vs 컨테이너
- **이미지**: 실행 파일들을 담은 읽기 전용 설계도/스냅샷 (예: `nginx:latest`)
- **컨테이너**: 이미지를 실제 실행한 인스턴스(프로세스). 이미지 하나로 컨테이너 여러 개 실행 가능.

### 쿠버네티스와의 연결
쿠버네티스는 컨테이너를 직접 만들지 않고, 이미 만들어진 컨테이너(Docker 등)를 여러 서버에 걸쳐 스케줄링·관리. K8s에서는 컨테이너를 직접 다루지 않고 이를 감싼 **Pod** 단위로 다룸 → 다음 학습 주제.

## Pod란?

쿠버네티스에서 **배포 가능한 가장 작은 단위**. 컨테이너 1개(또는 여러 개)를 감싸는 포장 껍질.

- 쿠버네티스는 컨테이너를 개별로 스케줄링하지 않고 반드시 Pod 단위로 다룸
- 대부분 Pod 안에 컨테이너 1개. 여러 개는 사이드카 패턴처럼 긴밀히 협력해야 할 때만.

### 같은 Pod 안 컨테이너 특징
- **네트워크 공유**: 같은 IP, `localhost`로 서로 통신
- **스토리지(볼륨) 공유** 가능
- **항상 같은 노드에 함께 배치**, 함께 생성/삭제됨

→ Pod = "한 몸처럼 움직여야 하는 컨테이너 묶음"

### Pod가 필요한 이유
컨테이너 여러 개가 IP를 공유하며 긴밀히 협업해야 하는 경우(앱 + 로그 수집 사이드카 등)를 표현하기 위해, "항상 세트로 스케줄링/재시작"되는 상위 단위가 필요했음.

### 중요한 특징: Pod는 일회용
- **불변(immutable)**: 생성 후 스펙 수정 불가 → 바꾸려면 삭제 후 재생성
- **언제든 죽을 수 있고, 죽으면 IP도 바뀜** (노드 장애, 스케일 조정 등)
- 그래서 Pod를 직접 만들어 쓰는 경우는 드물고, 보통 Pod를 자동 생성/유지해주는 상위 오브젝트인 **Deployment**를 통해 다룸 → 다음 학습 주제

### 클러스터에서 확인
`kubectl get pods -A`로 봤던 `coredns-...`, `etcd-...` 등이 전부 Pod. 이미 시스템이 여러 Pod로 동작 중임을 확인함.

## Deployment란?

Pod를 원하는 개수만큼 자동으로 만들고 그 상태를 계속 유지해주는 상위 오브젝트. 실무에서 앱 배포 시 가장 많이 쓰는 단위.

### 필요한 이유
Pod는 불변(수정 불가) + 언제든 죽을 수 있음(자동 재생성 안 됨) → Deployment가 "원하는 상태(desired state)"를 선언하면 계속 유지해줌.

### 계층 구조
```
Deployment (원하는 상태 선언 + 배포 전략)
  ↓ 자동 생성
ReplicaSet (실제 개수 감시, 부족하면 채움)
  ↓ 자동 생성
Pod, Pod, Pod (실행 단위)
```
실무에서 ReplicaSet을 직접 다룰 일은 거의 없음 — Deployment가 알아서 관리.

### 핵심 기능
- **Self-healing**: Pod 죽으면 자동으로 새 Pod 생성
- **스케일링**: `kubectl scale`로 개수 조정
- **롤링 업데이트**: 이미지 버전 변경 시 Pod를 하나씩 순차 교체 (무중단)
- **롤백**: 문제 생기면 이전 버전으로 복귀 가능

### YAML 예시
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
```
`replicas: 3`이 "원하는 상태" 선언. `kubectl apply`로 적용하면 쿠버네티스가 계속 그 상태를 지킴 → **선언적(Declarative) 관리**, K8s 전체를 관통하는 핵심 철학.

### 정리
- Pod = 실행 단위 (일회용, 불안정)
- ReplicaSet = Pod 개수 유지 (Deployment가 자동 관리)
- Deployment = 실무에서 실제로 다루는 단위

→ 실무에서는 Pod를 직접 만들지 않고 거의 항상 Deployment를 통해 배포함.

## Service란?

여러 Pod에 안정적으로 접근할 수 있게 해주는 고정된 접속 지점. Pod 앞단의 "고정 IP + 로드밸런서" 역할.

### 필요한 이유
Pod는 재생성될 때마다 IP가 바뀜 → 다른 앱이 Pod IP를 직접 알고 통신하면 Pod 재시작 시 장애 발생. Service가 고정 주소를 두고 그 뒤의 실제 Pod로 요청을 자동 전달해 해결.

### 동작 원리
- **Label(라벨)** 기준으로 어떤 Pod들에게 트래픽을 보낼지 결정 (Label Selector)
- Pod가 죽고 새로 생겨도 같은 라벨이면 Service가 자동으로 추적/연결
- 선언적으로 정의: "이 라벨을 가진 Pod들한테 트래픽 보내줘"

### 3가지 주요 타입
| 타입 | 설명 | 범위 |
|---|---|---|
| ClusterIP (기본값) | 클러스터 내부 전용 가상 IP | 내부만 (백엔드↔DB 등) |
| NodePort | 각 노드의 특정 포트로 외부 접근 가능 | 외부 (개발/테스트용) |
| LoadBalancer | 클라우드(GKE/EKS/AKS)의 로드밸런서 자동 생성 | 외부 (운영 표준) |

### YAML 예시
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx        # Deployment의 labels: app: nginx 와 매칭
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```
Deployment의 `labels`와 Service의 `selector`가 연결되는 게 핵심 — Deployment가 만든 Pod들 = Service selector가 찾는 대상.

### 3종 세트 흐름 정리
```
Deployment → Pod 3개 유지 (라벨: app=nginx)
                ↑ selector로 연결
Service    → app=nginx 라벨 Pod들에 고정 주소로 접근 가능하게 함
```
Pod + Deployment + Service = 쿠버네티스에서 가장 기본적으로 함께 쓰이는 3종 세트. 이 조합으로 간단한 앱 배포/노출까지 가능.

## 롤링 업데이트(Rolling Update)란?

Deployment의 이미지 버전(또는 스펙)을 바꿀 때, Pod를 한꺼번에 다 교체하지 않고 몇 개씩 순차적으로 바꿔가며 **무중단으로 배포**하는 방식.

### 필요한 이유
3개 Pod를 한 번에 다 내리고 새 버전으로 띄우면, 교체되는 동안 서비스가 완전히 죽는 다운타임 발생. 롤링 업데이트는 항상 일정 개수 이상의 Pod가 살아서 트래픽을 받는 상태를 유지하며 점진적으로 교체.

### 동작 원리
이미지 버전을 바꾸면 Deployment는 새 버전을 위한 **새 ReplicaSet**을 만들고, 기존 ReplicaSet은 점점 줄이면서 새 ReplicaSet을 점점 늘림.

```
[변경 전] 기존 ReplicaSet (v1): Pod 3개
      ↓ 이미지 버전 변경
[진행 중] 기존 ReplicaSet (v1): 3 → 2 → 1 → 0
          새 ReplicaSet   (v2): 0 → 1 → 2 → 3
[완료]  새 ReplicaSet(v2) 3개, 기존 ReplicaSet(v1)은 0개지만 기록은 남음 (롤백용)
```

한 번에 몇 개씩 교체할지는 두 옵션으로 조절:

| 옵션 | 의미 | 기본값 |
|---|---|---|
| `maxUnavailable` | 업데이트 중 동시에 내려가도 되는 Pod 최대 개수 | 25% |
| `maxSurge` | 원래 개수보다 초과해서 띄워도 되는 Pod 최대 개수 | 25% |

### YAML 예시
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
```
안 써도 기본 전략이 RollingUpdate라 자동 적용됨.

### 관련 명령어
| 명령어 | 역할 |
|---|---|
| `kubectl set image deployment/이름 컨테이너명=이미지:버전` | 이미지 버전 변경 → 롤링 업데이트 트리거 |
| `kubectl rollout status deployment/이름` | 진행 상황 실시간 확인 |
| `kubectl rollout history deployment/이름` | 배포 이력 확인 |
| `kubectl rollout undo deployment/이름` | 바로 직전 버전으로 롤백 |

### 정리
- 목적: 무중단 배포
- 방법: 새 ReplicaSet을 늘리면서 기존 ReplicaSet을 줄임
- 문제 생기면 `rollout undo`로 즉시 롤백 가능 — 이전 ReplicaSet이 남아있어서 가능

## 스케일링(Scaling)이란?

Deployment가 유지하는 Pod 개수(`replicas`)를 늘리거나 줄이는 것. 트래픽이 늘면 Pod를 늘려 부하를 분산하고, 줄면 다시 줄여 자원을 아낌.

### 방법
| 방법 | 명령어/설정 | 특징 |
|---|---|---|
| 수동 스케일링 | `kubectl scale deployment/이름 --replicas=5` | 지금 당장 개수를 명시적으로 지정 |
| YAML 수정 | `replicas: 5`로 바꾸고 `kubectl apply` | 선언적 방식, 코드로 관리 (실무에서 더 선호) |
| 자동 스케일링(HPA) | `kubectl autoscale` / `HorizontalPodAutoscaler` | CPU/메모리 사용률 등 지표 기반으로 자동 조절 (추후 별도 주제) |

### 동작 원리
Deployment의 `replicas` 값을 바꾸면 ReplicaSet이 그 숫자에 맞춰 Pod를 추가 생성하거나 초과분을 삭제.

```
kubectl scale --replicas=5
     ↓
기존 ReplicaSet: Pod 3개 → 5개 (2개 새로 생성)
```

**롤링 업데이트와의 차이**: 롤링 업데이트는 이미지가 바뀌어서 **새 ReplicaSet**이 생기지만, 스케일링은 이미지는 그대로고 개수만 바뀌는 거라 **기존 ReplicaSet 그대로 Pod 개수만** 조정됨. 줄일 때 어떤 Pod가 삭제될지는 K8s가 알아서 선택.

### 정리
- 목적: 부하에 맞게 Pod 개수 조절 (수평 확장/축소)
- 롤링 업데이트: ReplicaSet이 바뀜 / 스케일링: 같은 ReplicaSet 안에서 개수만 바뀜

## ConfigMap이란?

애플리케이션의 **설정값을 컨테이너 이미지/코드와 분리**해서 관리할 수 있게 해주는 오브젝트. 환경변수, 설정 파일 내용 등을 담아두고 Pod에 주입해서 씀.

### 필요한 이유
설정값(DB 주소, 로그 레벨, 기능 플래그 등)을 코드/이미지에 하드코딩하면 설정 하나 바꿀 때마다 이미지를 다시 빌드해야 하고, 환경(개발/스테이징/운영)마다 다른 이미지가 필요해짐. ConfigMap을 쓰면 **같은 이미지**를 그대로 두고 환경별로 다른 ConfigMap만 연결해 설정을 다르게 줄 수 있음.

### Pod에 주입하는 방법
| 방법 | 설명 |
|---|---|
| 환경변수(`envFrom`/`env`) | ConfigMap의 key-value를 컨테이너 환경변수로 주입 |
| 볼륨(파일)로 마운트 | ConfigMap 내용을 파일로 만들어 컨테이너 안 특정 경로에 마운트 |

### YAML 예시
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  GREETING: "Hello from ConfigMap"
  LOG_LEVEL: "debug"
```
```yaml
# Deployment 쪽에서 참조
containers:
  - name: nginx
    envFrom:
      - configMapRef:
          name: nginx-config
```

### 중요한 특징
- **환경변수로 주입한 경우, ConfigMap을 수정해도 이미 떠있는 Pod에는 반영 안 됨** — 환경변수는 컨테이너 시작 시점에 한 번 값이 고정되기 때문. 반영하려면 Pod를 재생성해야 함 (`kubectl rollout restart` 등)
- **볼륨(파일)로 마운트한 경우는 시간차를 두고 파일 내용이 자동 갱신됨** (kubelet이 주기적으로 동기화) — 다만 앱이 그 파일 변경을 다시 읽어야 실제로 반영됨
- **민감한 정보(비밀번호, API 키 등)는 ConfigMap에 넣으면 안 됨** — 평문 저장이라 누구나 조회 가능. 그런 건 **Secret**을 사용 (구조는 거의 같지만 base64 인코딩 + 접근 제어가 추가됨)

### 정리
- 목적: 설정을 코드와 분리해서 이미지 재빌드 없이 환경별로 다른 설정 적용
- 환경변수 주입은 Pod 재생성 필요, 파일 마운트는 자동 동기화(단, 앱이 다시 읽어야 함)
- 민감 정보는 ConfigMap이 아니라 Secret으로

## Secret이란?

ConfigMap과 구조는 거의 같지만, **민감한 정보**(비밀번호, API 키, 인증서, 토큰 등)를 다루기 위한 전용 오브젝트.

### ConfigMap과 다른 점
| | ConfigMap | Secret |
|---|---|---|
| 용도 | 일반 설정값 | 민감한 정보 |
| 저장 방식 | 평문 | **base64 인코딩** (암호화 아님, 인코딩일 뿐) |
| `kubectl get -o yaml` | 값이 그대로 보임 | base64로 인코딩되어 보임 |
| 접근 제어 | 상대적으로 느슨 | RBAC으로 더 엄격하게 제한 가능 |

**중요**: base64는 암호화가 아니라 그냥 인코딩. `base64 -d`로 누구나 즉시 원문을 볼 수 있음. Secret 자체가 "완벽히 안전"한 게 아니라, 민감정보임을 명시하고 접근을 통제하기 쉬운 형태로 관리하는 정도. 진짜 강력한 보안이 필요하면 Vault 같은 외부 secret 관리 도구를 연동.

### Pod에 주입하는 방법
ConfigMap과 동일 — 환경변수(`envFrom`/`env`) 또는 볼륨 마운트. 반영 시점 등 동작 원리도 ConfigMap과 같음.

### YAML 예시
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: nginx-secret
type: Opaque
data:
  DB_PASSWORD: cGFzc3dvcmQxMjM=   # echo -n 'password123' | base64
```
`stringData`를 쓰면 평문으로 적어도 K8s가 알아서 base64로 저장해줌 (직접 인코딩 안 해도 돼서 실무에서 더 자주 씀):
```yaml
stringData:
  DB_PASSWORD: password123
```

### 타입(`type`)
- `Opaque` (기본값): 임의의 key-value, 가장 흔히 씀
- `kubernetes.io/dockerconfigjson`: 프라이빗 이미지 레지스트리 인증 정보
- `kubernetes.io/tls`: TLS 인증서/키 (Ingress에서 다시 등장)

### 정리
- 목적: 민감정보를 ConfigMap과 분리해서 명시적으로 관리
- base64는 암호화가 아님 — 진짜 보안은 접근 제어(RBAC)나 외부 도구
- `stringData`로 평문 입력하면 K8s가 자동으로 인코딩