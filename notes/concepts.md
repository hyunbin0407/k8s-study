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

## Namespace란?

하나의 쿠버네티스 클러스터 안에서 리소스들을 **논리적으로 나누는 가상의 구역**. 지금까지 실습에서 아무 옵션 없이 쓰던 게 사실 `default`라는 이름의 Namespace 안이었음.

### 필요한 이유
클러스터 하나를 여러 팀/프로젝트/환경이 같이 쓸 때, 이름이 겹치거나 리소스가 뒤섞이는 걸 막기 위함.
- **환경 분리**: `dev`/`staging`/`production`을 같은 클러스터에서 격리
- **팀/프로젝트 분리**: RBAC과 결합해 팀별 접근 권한 통제 가능
- **리소스 관리**: Namespace별 CPU/메모리 사용량 제한(ResourceQuota) 가능

### 이미 써왔던 개념
`kubectl get pods -A`의 `-A`가 모든 Namespace를 조회하는 옵션. `kube-system`, `local-path-storage`가 전부 Namespace 이름이고, 우리가 만든 nginx는 항상 `default` Namespace였음.

### 동작 원리
- 대부분 리소스(Pod, Deployment, Service, ConfigMap, Secret 등)는 특정 Namespace에 속함 — **Namespaced 리소스**
- Node, PersistentVolume 등 클러스터 전체에 걸친 건 Namespace 없음 — **Cluster-scoped 리소스**
- 같은 이름이어도 **Namespace가 다르면 별개의 리소스**

### YAML 예시
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: dev
```
```bash
kubectl apply -f deployment.yaml -n dev
kubectl get pods -n dev
```

### 서로 다른 Namespace 간 통신
같은 Namespace 안에서는 Service 이름만으로 접근 가능하지만(`nginx-service`), 다른 Namespace에서 접근하려면 `<서비스이름>.<네임스페이스>.svc.cluster.local` 형식의 전체 DNS 이름 필요.

### 정리
- 목적: 하나의 클러스터를 논리적으로 나눠서 격리·관리
- 지정 안 하면 전부 `default` Namespace
- 같은 이름이라도 Namespace가 다르면 별개 리소스

## Volume / PersistentVolume이란?

컨테이너/Pod가 사용하는 **데이터를 저장하는 공간**. 컨테이너는 재시작되면 그 안의 파일이 전부 사라지는데(불변/일회용), Volume을 쓰면 데이터를 컨테이너 생명주기와 분리해서 유지할 수 있음.

### 필요한 이유
컨테이너 안에 쓴 파일은 컨테이너가 죽으면 같이 사라짐 (이미지는 읽기 전용, 컨테이너의 쓰기 레이어는 임시). DB 데이터, 업로드 파일처럼 없어지면 안 되는 데이터는 컨테이너 밖의 별도 저장 공간에 둬야 함.

### 두 가지 레벨
| | Volume | PersistentVolume(PV) |
|---|---|---|
| 생명주기 | **Pod와 함께** 생성/삭제 | Pod와 **무관하게** 독립적으로 존재 |
| 용도 | 같은 Pod 안 컨테이너 간 파일 공유, 임시 캐시 | Pod가 재생성돼도 계속 남아야 하는 데이터 |
| 예시 타입 | `emptyDir`, `configMap`(ConfigMap 실습에서 이미 사용), `hostPath` | `PersistentVolume` + `PersistentVolumeClaim` |

지난 ConfigMap 실습의 `volumes:`/`volumeMounts:`가 사실 이미 Volume이었음. 이번엔 그중 "Pod가 죽어도 데이터가 남는" PersistentVolume을 다룸.

### PV / PVC 구조
```
PersistentVolume (PV)        ← 실제 저장 공간 (클러스터 관리자가 준비)
      ↑ 연결(bind)
PersistentVolumeClaim (PVC)  ← "이만큼 용량 주세요" 요청 (개발자가 작성)
      ↑ 참조
Pod                           ← PVC를 volume으로 마운트해서 사용
```
개발자는 PV를 직접 안 다루고 PVC로 용량만 요청 — 실제 어떤 디스크인지 몰라도 됨(관심사 분리).

### YAML 예시
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```
```yaml
volumes:
  - name: html-storage
    persistentVolumeClaim:
      claimName: nginx-pvc
```
Docker Desktop 환경에서는 `local-path-provisioner`(시스템 Pod 중 하나)가 PVC 요청이 들어오면 자동으로 PV를 만들어줌 (StorageClass 기반 동적 프로비저닝).

### 정리
- Volume: Pod 생명주기에 종속 / PersistentVolume: Pod와 무관하게 독립 생존
- 개발자는 PVC로 용량만 요청, K8s가 알아서 PV와 연결
- PVC를 지우면(ReclaimPolicy가 Delete인 경우) 실제 데이터도 같이 삭제됨

## Ingress란?

여러 Service를 하나의 진입점으로 묶어서, **HTTP(S) 경로/도메인 기반으로 외부 트래픽을 라우팅**해주는 오브젝트. 앱들 앞에 서는 똑똑한 리버스 프록시.

### 필요한 이유
Service의 `LoadBalancer` 타입은 서비스 하나당 로드밸런서(외부 IP)가 하나씩 필요 — 앱이 여러 개면 비용/관리 부담 커짐. Service는 L4(TCP/IP) 레벨이라 "경로별로 다른 앱에 연결" 같은 세밀한 라우팅도 못 함. Ingress는 외부 진입점 하나로 여러 Service를 도메인/경로 기준으로 나눠 연결.

### 동작 원리
```
외부 요청 → Ingress Controller(nginx 등 실제 프록시) → Ingress 규칙에 따라 분기
                                                          ├─ Service A (/app1)
                                                          ├─ Service B (/app2)
                                                          └─ Service C (api.example.com)
```
**중요**: Ingress는 규칙(YAML)일 뿐이고, 실제 트래픽을 처리하는 건 **Ingress Controller**(별도 설치 필요한 프록시 소프트웨어, 대표적으로 nginx-ingress). Deployment/Service는 K8s에 기본 내장이지만 Ingress는 컨트롤러를 따로 설치해야 동작한다는 게 가장 큰 차이.

### YAML 예시
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
    - host: nginx.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```
`host`로 도메인 기반, `path`로 경로 기반 라우팅. 하나의 Ingress 안에 여러 규칙을 넣어 여러 앱을 동시에 노출 가능.

### Service 타입과의 비교
| | ClusterIP | NodePort | LoadBalancer | Ingress |
|---|---|---|---|---|
| 계층 | L4 | L4 | L4 | **L7 (HTTP)** |
| 외부 노출 | ✗ | ✓ (포트) | ✓ (IP) | ✓ (도메인/경로) |
| 여러 앱 통합 | - | - | 앱당 하나씩 | **하나로 여러 앱 라우팅** |
| 별도 설치 필요 | ✗ | ✗ | ✗(클라우드면 자동) | **✓ (Controller 필요)** |

실무에서는 각 앱을 `ClusterIP` Service로만 노출하고, 그 앞에 Ingress 하나를 세워 외부와 연결하는 구조가 일반적 (LoadBalancer는 Ingress Controller 자신을 노출시킬 때 한 번만 사용).

### 정리
- 목적: 여러 Service를 도메인/경로 기준으로 하나의 진입점에서 라우팅
- Ingress(규칙) + Ingress Controller(실제 프록시) 조합으로 동작 — 컨트롤러 설치가 선행 필요
- L7(HTTP) 레벨이라 Service보다 더 세밀한 라우팅 가능

## StatefulSet이란?

Deployment와 비슷하게 Pod를 여러 개 관리하지만, **각 Pod가 고유한 정체성을 가지고 순서대로 다뤄져야 하는** 앱(대표적으로 DB)을 위한 오브젝트.

### 필요한 이유
Deployment는 Pod들을 전부 "다 똑같은 복제본"으로 취급함 — 이름도 랜덤 해시, 어떤 Pod가 죽어도 그냥 새 걸로 대체, 순서 신경 안 씀. stateless 앱엔 딱 맞지만, DB 클러스터처럼 각 인스턴스가 고유 역할(리더/팔로워)을 갖거나 순서대로 뜨고 죽어야 하거나 각자 자기만의 저장 공간을 유지해야 하는 경우엔 부족함.

### Deployment와의 핵심 차이
| | Deployment | StatefulSet |
|---|---|---|
| Pod 이름 | 랜덤 해시 (`nginx-abc123-xyz`) | **고정 번호** (`postgres-0`, `postgres-1`...) |
| 생성/삭제 순서 | 동시에(병렬) | **순차적** (0번부터, 삭제는 큰 번호부터 역순) |
| 네트워크 정체성 | Pod IP 바뀌면 그만 | 각 Pod가 **고유한 DNS 이름** 보유 (재시작해도 유지) |
| 스토리지 | PVC 하나를 공유하거나 안 씀 | **Pod마다 전용 PVC**가 자동 생성됨 |
| 대표 용도 | 웹서버, API 서버 (stateless) | DB, 메시지 큐, 분산 저장소 (stateful) |

### 새로 등장하는 개념
- **`volumeClaimTemplates`**: PVC를 따로 만들어 연결하는 대신, StatefulSet이 Pod를 만들 때마다 **전용 PVC를 자동 생성**. `postgres-0`엔 `<템플릿이름>-postgres-0`이라는 PVC가 개별로 붙음
- **Headless Service** (`clusterIP: None`): 여러 Pod를 하나의 고정 IP 뒤로 숨기는 일반 Service와 달리, 각 Pod에 개별적으로 이름으로 접근 가능하게 함 (`postgres-0.postgres-headless.webapp.svc.cluster.local`)

### YAML 예시 (핵심 차이만)
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless   # Headless Service 필요
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
  volumeClaimTemplates:
    - metadata:
        name: postgres-storage
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

### 정리
- Deployment: 다 똑같은 복제본, 이름/저장공간 공유 → stateless 앱용
- StatefulSet: 각 Pod가 고유 이름·고유 저장공간·순서 보장 → stateful 앱(DB 등)용
- `volumeClaimTemplates`로 Pod마다 전용 PVC 자동 생성, Headless Service로 개별 Pod 지목 가능

## HPA (Horizontal Pod Autoscaler)란?

3회차 수동 스케일링(`kubectl scale`)을 **자동화**한 것. CPU 사용률(또는 다른 지표) 기준으로 Pod 개수를 K8s가 알아서 늘리고 줄여줌.

### 필요한 이유
수동 스케일링은 사람이 트래픽을 보고 판단해서 명령어를 쳐야 함. HPA는 "CPU 사용률 50% 넘으면 자동으로 늘려라" 같은 규칙을 걸어두면, K8s가 주기적으로 지표를 체크하며 알아서 `kubectl scale`을 대신 실행.

### 동작 원리
```
Metrics Server (Pod들의 CPU/메모리 사용량 수집)
      ↓
HPA 컨트롤러가 주기적으로 확인 (기본 15초마다)
      ↓
목표 대비 사용률 높음 → replicas 늘림 / 훨씬 낮음 → replicas 줄임
      ↓
Deployment의 replicas 필드를 실제로 수정 (kubectl scale과 동일한 내부 동작)
```
**중요**: HPA는 CPU 등 지표를 알아야 하는데, 기본 K8s는 이걸 안 모음. **`metrics-server`라는 별도 컴포넌트 설치가 선행 필요** (8회차 Ingress Controller와 같은 패턴 — K8s 기본 내장이 아님).

### YAML 예시
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: adminer-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: adminer-deployment
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```
- `scaleTargetRef`: 대상 Deployment/StatefulSet
- `minReplicas`/`maxReplicas`: 자동 스케일링 하한/상한선
- `averageUtilization: 50`: 평균 CPU 사용률이 요청 리소스의 50% 넘으면 확장

**주의**: CPU 기준 HPA가 작동하려면 컨테이너에 `resources.requests.cpu`가 **반드시 설정**되어야 함 — 사용률(%)은 "요청값 대비 몇 %"라서 기준값 없이는 계산 불가.

### 관련 명령어
| 명령어 | 역할 |
|---|---|
| `kubectl autoscale deployment/이름 --min=1 --max=5 --cpu-percent=50` | 명령어로 HPA 즉석 생성 |
| `kubectl get hpa` | 현재 HPA 상태(목표 대비 현재 사용률, replicas) 확인 |
| `kubectl top pods` | Pod별 실시간 CPU/메모리 사용량 확인 (metrics-server 필요) |

### 정리
- 목적: 트래픽에 따라 사람 개입 없이 자동으로 Pod 개수 조절
- `metrics-server` 설치가 선행 필요
- CPU 기준 스케일링엔 `resources.requests.cpu` 설정 필수
- `minReplicas`/`maxReplicas`로 안전 범위 설정

## RBAC (Role-Based Access Control)이란?

**"누가 무엇을 할 수 있는가"**를 정의하는 쿠버네티스의 권한 관리 시스템.

### 필요한 이유
- 사람: 신입 개발자가 실수로 운영 DB를 `kubectl delete`하면 안 되니 조회만 가능하게 제한
- 앱(Pod): 앱이 굳이 다른 Namespace나 Secret까지 건드릴 수 있을 필요는 없음 — 최소 권한 원칙
- 팀/프로젝트: Namespace로 리소스는 나눴어도, "이 Namespace는 이 팀만" 하려면 RBAC 필요

### 핵심 개념 4가지
| 오브젝트 | 역할 |
|---|---|
| **Role** | 특정 Namespace 안에서 할 수 있는 행동 목록 정의 |
| **ClusterRole** | Role과 같지만 클러스터 전체 또는 Namespace 없는 리소스(Node 등)에 사용 |
| **RoleBinding** | 특정 Namespace 안에서 "누구에게 이 Role을 준다"를 연결 |
| **ClusterRoleBinding** | ClusterRole을 클러스터 전체에 걸쳐 연결 |

```
Role/ClusterRole (권한 목록) + RoleBinding/ClusterRoleBinding (누구에게) = 실제 권한 부여
```
Role만 만들고 아무한테도 안 주면(Binding 없으면) 아무 효과 없음.

### ServiceAccount — Pod(앱)의 신분증
사람은 계정으로, Pod 안에서 실행되는 앱이 쿠버네티스 API를 호출할 땐 `ServiceAccount`로 식별됨. 아무것도 지정 안 하면 Namespace마다 자동으로 있는 `default` ServiceAccount를 씀.

### YAML 예시
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: webapp
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]   # 조회만, 생성/삭제 불가
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: webapp
subjects:
  - kind: ServiceAccount
    name: readonly-sa
    namespace: webapp
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```
`rules`의 구조: `apiGroups`(기본 리소스는 `""`, Deployment는 `"apps"`) + `resources`(대상 리소스) + `verbs`(허용 동작: get/list/watch/create/update/delete 등)

### 정리
- Role(권한 목록) + RoleBinding(누구에게) = 실제 권한
- Role/RoleBinding은 특정 Namespace 안에서만, ClusterRole/ClusterRoleBinding은 클러스터 전체
- 앱(Pod)은 ServiceAccount로 식별, 지정 안 하면 `default` ServiceAccount 사용
- 최소 권한 원칙: 필요한 것만 딱 허용

## Helm이란?

쿠버네티스용 **패키지 매니저**. 여러 YAML 리소스를 하나의 패키지(Chart)로 묶어서 설치·업그레이드·롤백을 관리.

### 필요한 이유
YAML 파일이 여러 개면(우리 webapp 프로젝트처럼 18개) 순서대로 하나씩 `kubectl apply` 해야 하고, 설정값을 바꾸려면 YAML을 직접 찾아 고쳐야 하며, 환경별(dev/staging/prod)로 조금씩 다르게 배포하려면 YAML을 복붙해서 유지보수해야 함. Helm은 YAML을 "템플릿"으로 만들고 값(`values.yaml`)만 갈아끼우면 여러 리소스가 한 번에 렌더링되게 해줌.

### 핵심 개념
| 용어 | 의미 |
|---|---|
| **Chart** | 패키지 자체 — 템플릿 YAML들 + 기본 설정값을 담은 디렉토리 |
| **Values** | Chart에 주입하는 실제 설정값 (`values.yaml` 또는 `--set`) |
| **Template** | `{{ .Values.xxx }}` 변수가 박힌 YAML — 적용 전 값으로 치환(렌더링) |
| **Release** | Chart를 클러스터에 실제로 설치한 인스턴스 |
| **Repository** | Chart 저장소 (남이 만든 Chart도 가져다 쓸 수 있음, 예: Bitnami) |

### Chart 구조 & 템플릿 예시
```
webapp-chart/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── postgres-deployment.yaml
    └── adminer-deployment.yaml
```
```yaml
# templates/adminer-deployment.yaml
spec:
  replicas: {{ .Values.adminer.replicas }}
```
```yaml
# values.yaml
adminer:
  replicas: 4
```

### 롤백 — 2회차 개념의 확장
`kubectl rollout undo`가 Deployment 하나만 롤백했다면, Helm은 **여러 리소스를 묶은 Release 전체**를 하나의 단위로 버전 관리해서 통째로 롤백 가능.

| | `kubectl rollout` | Helm |
|---|---|---|
| 관리 단위 | Deployment 하나 | Release(여러 리소스 묶음) |
| 롤백 | `kubectl rollout undo` | `helm rollback <release> <리비전>` |
| 이력 | `kubectl rollout history` | `helm history <release>` |

### 관련 명령어
| 명령어 | 역할 |
|---|---|
| `helm install <이름> <Chart경로>` | Chart 설치 (Release 생성) |
| `helm upgrade <이름> <Chart경로>` | Release 업데이트 |
| `helm rollback <이름> <리비전>` | 이전 버전으로 롤백 |
| `helm list` | 설치된 Release 목록 |
| `helm uninstall <이름>` | Release 전체 삭제 |
| `helm template <Chart경로>` | 렌더링 결과만 미리보기 |

### 정리
- 목적: 여러 K8s YAML을 하나의 재사용 가능한 패키지로 관리
- Values로 설정 분리 → 환경별 배포가 쉬워짐
- Release 단위로 설치/업그레이드/롤백 이력 관리 (여러 리소스를 한 번에)

## Prometheus + Grafana (모니터링 스택)란?

클러스터와 앱의 상태를 **시간에 따라 기록하고, 그래프로 보여주는** 관찰성(Observability) 도구 조합.

### 필요한 이유
12회차의 `metrics-server`는 "지금 이 순간" 지표만 메모리에 잠깐 들고 있음(`kubectl top`은 순간값만). Prometheus는 지표를 시계열 데이터베이스에 계속 쌓아서, 과거 추이까지 조회·그래프화 가능.

### 역할 분담
| | Prometheus | Grafana |
|---|---|---|
| 역할 | 지표 수집 + 저장 + 질의(PromQL) | 지표 시각화(대시보드, 그래프) |
| 데이터 소스 | 각 Pod/Node의 `/metrics`를 주기적으로 긁어옴(pull) | Prometheus에 질의해서 결과를 받아옴 |

### metrics-server와의 차이
| | metrics-server | Prometheus |
|---|---|---|
| 저장 기간 | 현재 스냅샷만 | 장기간 시계열 |
| 용도 | HPA 스케일링 판단용 최소 데이터 | 대시보드, 알림, 장애 분석 |
| 조회 | `kubectl top` | PromQL, Grafana 대시보드 |

**중요**: 경쟁 관계가 아니라 공존 — metrics-server는 HPA용으로 계속 두고 Prometheus는 별개로 추가.

### kube-prometheus-stack
Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics를 한 번에 묶은 커뮤니티 Helm Chart. Helm으로 남이 만든 공식 Chart를 설치하는 방식.
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### CRD (Custom Resource Definition)
쿠버네티스 API 자체를 확장해서 새로운 `kind`를 쓸 수 있게 해주는 메커니즘. `kube-prometheus-stack`의 `ServiceMonitor`가 대표적 — "이 라벨을 가진 Service를 Prometheus가 자동으로 스크래핑하게 해줘"라는 뜻으로, Service의 라벨 셀렉터와 비슷하게 동작.

### 정리
- Prometheus: 지표 시계열 수집·저장, PromQL로 질의
- Grafana: Prometheus 데이터를 대시보드로 시각화
- metrics-server(스냅샷, HPA용)와 Prometheus(장기 저장, 관찰성용)는 공존
- `kube-prometheus-stack` Helm Chart로 한 번에 설치가 사실상 표준
- ServiceMonitor 같은 CRD로 쿠버네티스 API를 확장해서 사용

## GitOps / ArgoCD란?

**Git 저장소를 "클러스터가 어떤 상태여야 하는가"에 대한 유일한 진실 공급원으로 삼고, 클러스터 안의 컨트롤러가 그 상태를 계속 따라가도록(pull) 만드는 운영 방식**. ArgoCD가 이걸 구현하는 대표 도구.

### 필요한 이유
지금까지는 사람이 직접 `kubectl apply`/`helm install`을 실행해야 클러스터가 바뀜 — 실수로 안 하거나, 다른 값을 넣거나, "지금 클러스터가 Git과 정말 일치하는지" 확인할 방법이 마땅치 않음. GitOps는 Git에 원하는 상태를 커밋해두면 클러스터 안의 에이전트가 알아서 감지·반영하게 함.

### 전통적 CI/CD(Push)와의 차이
```
[전통적 CI/CD - Push] 개발자 → git push → CI 서버가 kubectl/helm 실행 → 클러스터
                       (클러스터가 외부에서 접근 가능해야 함)

[GitOps - Pull]        개발자 → git push → 끝
                       클러스터 안 ArgoCD → 주기적으로 Git 확인 → 차이 있으면 스스로 반영
                       (클러스터가 GitHub으로 나가기만 하면 됨, 외부 노출 불필요 — 로컬 클러스터에 적합)
```

### 핵심 개념: Application (CRD)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/사용자/레포.git
    path: helm/webapp-chart
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-gitops
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```
- `source`: 감시할 Git 레포 + 경로
- `destination`: 배포될 클러스터/Namespace
- `syncPolicy.automated`: 자동 동기화 여부
- `selfHeal: true`: 누군가 `kubectl edit`로 클러스터를 직접 고쳐도 Git 상태로 자동 복구 — 선언적 관리의 가장 강력한 형태

### 정리
- GitOps: Git = 원하는 상태의 유일한 기준, 클러스터가 Git을 따라감 (Pull 방식)
- ArgoCD: `Application`이라는 CRD로 "어느 레포를 감시할지" 정의
- `selfHeal`: 수동 변경도 Git 상태로 자동 복구
- 로컬/비공개 클러스터에 특히 적합 (클러스터가 외부에 노출될 필요 없음)

## 클러스터 아키텍처 / kubeadm / CNI란?

지금까지는 "이미 만들어진 클러스터" 위에서만 실습했음. 이번엔 그 클러스터 자체를 직접 만들어보기 위한 배경지식.

### 클러스터 구조: Control Plane vs Worker Node
```
┌─────── Control Plane (관제탑) ───────┐
│ etcd                    ← 클러스터 상태 저장 DB │
│ kube-apiserver          ← kubectl가 대화하는 창구 │
│ kube-scheduler          ← Pod를 어느 노드에 배치할지 결정 │
│ kube-controller-manager ← Deployment→ReplicaSet→Pod 등 조정 로직 │
└──────────────────────────────────────┘
┌─────── Worker Node (실제 앱이 도는 곳) ───────┐
│ kubelet          ← 이 노드에서 Pod를 실제 실행/관리 │
│ kube-proxy       ← Service 네트워킹 처리 │
│ Container Runtime(containerd) ← 컨테이너 실행 엔진 │
└───────────────────────────────────────┘
```
`kubectl get pods -n kube-system`에서 계속 봤던 `etcd-...`, `kube-apiserver-...` 등이 바로 이 컨트롤 플레인 구성요소 — Docker Desktop이 자동으로 만들어줬던 것.

### kubeadm
컨트롤 플레인 구성을 자동화해주는 공식 도구.
| 명령어 | 역할 |
|---|---|
| `kubeadm init` | 첫 서버에 Control Plane 전체를 자동 구성 |
| `kubeadm join` | 다른 서버를 워커 노드로 클러스터에 합류시킴 |

### CNI (Container Network Interface)
서로 다른 노드의 Pod들이 통신하는 네트워킹 계층. Docker Desktop은 `kindnet`이 미리 깔려있었지만, kubeadm으로 직접 만들면 **직접 설치**해야 함 (없으면 노드가 `NotReady`로 멈춤). 대표적으로 Calico, Flannel 등이 있음.

### 정리
- Control Plane(etcd/apiserver/scheduler/controller-manager) + Worker(kubelet/kube-proxy/runtime)
- `kubeadm init`으로 Control Plane 구축, `kubeadm join`으로 워커 합류
- CNI는 별도 설치 필요 — Docker Desktop이 자동으로 해주던 부분을 이번엔 직접

## kubeadm init이 실제로 하는 일 (18회차)

`kubeadm init` 한 줄이 컨트롤 플레인 전체를 만든다. 내부적으로 순서대로:

| 단계 | 하는 일 | 결과물 위치 |
|---|---|---|
| preflight | swap/cgroup 드라이버/포트/커널 모듈/런타임 점검 (17회차에서 맞춰둔 것들) | — |
| certs | 클러스터 전용 CA 생성 + 각 구성요소용 인증서 발급 (내부 통신은 전부 mTLS) | `/etc/kubernetes/pki/` |
| kubeconfig | apiserver에 접속할 관리자/구성요소용 접속 파일 생성 | `/etc/kubernetes/*.conf` |
| control-plane | etcd/apiserver/controller-manager/scheduler의 **static Pod** manifest 작성 | `/etc/kubernetes/manifests/` |
| kubelet | kubelet을 systemd로 기동 → 위 manifest 디렉토리를 감시하다 Pod 자동 실행 | — |
| bootstrap-token | 워커가 나중에 `kubeadm join`할 때 쓸 토큰 발급 | — |
| addon | kube-proxy, CoreDNS 배포 | `kube-system` NS |

### static Pod — 닭과 달걀 문제 해결법
apiserver도 Pod로 도는데, 그 apiserver를 만들려면 apiserver가 필요하다(모순). 그래서 컨트롤 플레인 4개는 **static Pod**로 뜬다 — kubelet이 `/etc/kubernetes/manifests/`의 YAML 파일을 직접 읽어서, 스케줄러·apiserver 없이 바로 실행한다. `kubectl get pods -n kube-system`에 보이긴 하지만 실제 정의는 그 파일에 있음(`kubectl delete`해도 kubelet이 즉시 되살림).

### 주요 플래그
| 플래그 | 의미 | 이번 실습 값 |
|---|---|---|
| `--pod-network-cidr` | Pod에 나눠줄 IP 대역. **CNI(Calico) 설정과 반드시 일치** | `10.244.0.0/16` |
| `--apiserver-advertise-address` | apiserver가 광고할 IP. VM은 인터페이스가 여러 개라 명시 권장 | `192.168.252.6` (k8s-control) |

- Pod CIDR로 Calico 기본값(`192.168.0.0/16`)을 안 쓰는 이유: VM 노드 IP가 `192.168.252.x`라 대역이 논리적으로 겹쳐 라우팅이 헷갈릴 수 있음 → `10.244.0.0/16`으로 분리.
- Service CIDR 기본값(`10.96.0.0/12`)은 노드/Pod와 안 겹치므로 그대로 둠.

### init 직후 상태 (정상)
- `kubectl get nodes` → `k8s-control`이 **`NotReady`** (CNI가 아직 없어서 — 19회차에 해결)
- `kubectl get pods -n kube-system` → etcd/apiserver/controller-manager/scheduler/kube-proxy는 `Running`, **CoreDNS 2개는 `Pending`** (CNI 없어 스케줄 불가 — 정상)
- 출력 맨 끝의 `kubeadm join ... --token ... --discovery-token-ca-cert-hash ...` 문자열을 저장해둘 것 (20회차에 사용). 잃어버리면 `kubeadm token create --print-join-command`로 재발급.

### kubeconfig / 컨텍스트
- `/etc/kubernetes/admin.conf`를 `~/.kube/config`로 복사해야 `kubectl`이 동작 (root 아닌 유저로 쓰려면 소유권도 변경).
- 이 kubeconfig는 **VM 안에만** 있음. Mac의 `kubectl`은 계속 Docker Desktop을 가리킴 — 이번 실습은 VM 안에서 `kubectl` 실행.

### 정리
- `kubeadm init` = preflight → CA/인증서 → kubeconfig → 컨트롤 플레인 static Pod → kubelet 기동 → 토큰 → 애드온
- 컨트롤 플레인 4대는 static Pod (`/etc/kubernetes/manifests/`)로 부트스트랩 모순을 피함
- `--pod-network-cidr`는 CNI와 짝을 맞춰야 함
- init 직후 노드 `NotReady` + CoreDNS `Pending`은 정상 — CNI 설치(19회차)로 풀림

## Calico 설치가 실제로 하는 일 (19회차)

CNI 플러그인의 역할: Pod에 IP 할당, veth pair로 Pod의 네트워크 네임스페이스를 노드에 연결, **노드 간** Pod 트래픽이 라우팅되게 설정. 이게 없으면 컨트롤 플레인이 떠 있어도 Pod끼리(그리고 노드끼리) 통신 불가 — 그래서 18회차 직후 노드가 `NotReady`였음.

### Calico 구성요소
| 구성요소 | 종류 | 역할 |
|---|---|---|
| `calico-node` | DaemonSet (노드마다 1개) | 실제 라우팅/iptables 규칙을 설정하는 에이전트 |
| `calico-kube-controllers` | Deployment | K8s API를 보고 Calico 리소스(IPPool 등) 동기화 |
| CRD 여러 개 | `IPPool`, `BGPConfiguration` 등 | Calico 전용 커스텀 리소스 |

### 동작 방식
- `--pod-network-cidr`로 준 대역(`10.244.0.0/16`)을 노드별로 더 작은 블록(기본 `/26`, 64개 IP)으로 쪼개 각 노드 kubelet에 할당
- 노드 간 Pod 트래픽은 기본적으로 **IP-in-IP 터널링**으로 라우팅 — 언더레이 네트워크(VM들의 `192.168.252.x`)가 Pod 서브넷을 몰라도 동작하게 해줌
- 설치는 `calico.yaml` 하나를 apply하는 것 (CRD/RBAC/DaemonSet/Deployment 전부 포함). 안의 `CALICO_IPV4POOL_CIDR` 값(기본 `192.168.0.0/16`)을 **`kubeadm init`에 준 값과 반드시 일치**시켜야 함 — 안 맞으면 Pod가 IP를 못 받음

### 설치 후 효과
kubelet이 "네트워크 준비됨"을 apiserver에 보고 → 노드의 `node.kubernetes.io/not-ready` taint 해제 → 노드 `Ready` → 그동안 그 taint 때문에 스케줄 못 되던 CoreDNS가 이제 `Running`으로 전환.

### 정리
- CNI = Pod 네트워킹 계층. Calico는 DaemonSet(에이전트) + Deployment(컨트롤러) + CRD로 구성
- Pod CIDR 값은 `kubeadm init`과 CNI 설정이 반드시 일치해야 함
- 설치 완료 신호 = 노드 `Ready` 전환 + CoreDNS `Running` 전환

## `kubeadm join`이 실제로 하는 일 (20회차)

`kubeadm init`이 컨트롤 플레인을 부트스트랩했다면, `kubeadm join`은 워커 노드를 기존 클러스터에 안전하게 편입시키는 과정.

### TLS Bootstrap — 토큰 + 해시 두 개가 필요한 이유
워커가 처음 접속할 때는 서로를 신뢰할 근거(인증서)가 없음. 이를 푸는 방식:

| 요소 | 역할 |
|---|---|
| `--token` | 워커→apiserver 방향 인증: "정당한 노드야"를 증명하는 1회용 공유 비밀 |
| `--discovery-token-ca-cert-hash` | apiserver→워커 방향 검증: 받은 CA 인증서가 진짜인지 확인 (중간자 공격 방지) |

토큰은 보안상 **기본 24시간 후 자동 만료**. 만료됐으면 `kubeadm token create --print-join-command`로 컨트롤 플레인에서 재발급(CA 해시는 그대로 유지됨, 클러스터의 CA가 안 바뀌므로).

### `join` 내부 단계
| 단계 | 하는 일 |
|---|---|
| preflight | 워커가 요구사항(swap off, containerd, 커널 모듈 등) 충족하는지 점검 |
| discovery | 토큰으로 apiserver 접속 → CA 인증서 받아 해시로 검증 |
| kubelet bootstrap | 검증된 CA로 kubelet용 kubeconfig(`/etc/kubernetes/kubelet.conf`) 생성 |
| register | kubelet이 apiserver에 자신을 새 Node 오브젝트로 등록 |

### 등록 후 자동으로 벌어지는 일
워커에는 컨트롤 플레인 컴포넌트(apiserver/etcd/scheduler/controller-manager)가 전혀 안 뜸. 대신 **DaemonSet들이 새 Node를 감지해 자동으로 Pod를 스케줄**:
- `kube-proxy` — 새 Node에 자동으로 뜸
- `calico-node` — 자동으로 뜨면서 그 노드용 Pod CIDR 서브블록(`/26`)을 자동 할당받음

사용자가 워커에서 직접 할 일은 `kubeadm join` 명령 실행 한 번뿐 — CNI를 워커에 따로 설치할 필요 없음(DaemonSet이 알아서 확장).

### 정리
- 토큰+해시 조합으로 워커↔컨트롤 플레인 상호 신뢰를 안전하게 수립 (TLS Bootstrap)
- 워커에는 컨트롤 플레인 컴포넌트 없음, kubelet + kube-proxy + calico-node + 일반 Pod만 실행
- DaemonSet(kube-proxy, calico-node)은 새 Node 등록을 감지해 자동 확장 — 수동 설치 불필요

## Control Plane Taint (21회차)

`kubeadm init`은 컨트롤 플레인 노드에 자동으로 taint를 겁니다: `node-role.kubernetes.io/control-plane:NoSchedule`.

- **Taint**란 노드에 붙이는 "거부 딱지" — 매칭되는 **Toleration**(견딤 표시)이 없는 Pod는 그 노드에 스케줄 안 됨.
- 목적: 프로덕션에서 컨트롤 플레인의 리소스(apiserver/etcd 등)를 일반 워크로드로부터 보호.
- 효과 = kubelet의 `not-ready` taint(18~19회차에서 본 것)와 같은 메커니즘, 다른 이유로 붙은 taint일 뿐 — 스케줄러가 taint를 보고 배제한다는 원리는 동일.
- **워커 1대뿐인 랩 환경의 함정**: taint를 그대로 두면 모든 워크로드 Pod가 워커 1대에만 몰려서 "노드별 분산"을 확인할 방법이 없음.
- 제거: `kubectl taint nodes <노드이름> node-role.kubernetes.io/control-plane:NoSchedule-` (끝의 `-`가 제거를 의미). 다시 걸려면 `-` 없이 같은 taint를 추가.

### 정리
- Taint(노드가 거는 거부) + Toleration(Pod가 갖는 견딤 허용)으로 "이 노드엔 이런 Pod만" 정책을 구현
- 컨트롤 플레인 taint는 기본으로 걸려있음 — 소규모 랩 클러스터에서 노드 분산을 보려면 제거가 필요할 수 있음