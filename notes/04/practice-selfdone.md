# 실습 04 — 직접 완주! ConfigMap

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. 기존 nginx Deployment+Service 재배포
2. `manifests/03-nginx-configmap.yaml` 작성(`GREETING`, `LOG_LEVEL: debug`) → `kubectl apply`로 ConfigMap 생성, `describe`로 데이터 확인
   - 1차 시도에서 nano 저장이 안 된 채 넘어갔던 실수 발견 → 파일이 실제로 없다는 걸 확인하고 다시 진행해서 정상 생성
3. `manifests/01-nginx-deployment.yaml`에 `envFrom.configMapRef`로 ConfigMap 연결 → apply
   - 이미지는 안 바뀌었지만 Pod 스펙(컨테이너 정의)이 바뀐 거라 자동으로 롤링 업데이트 발생, 새 ReplicaSet으로 Pod 전부 교체되는 것 확인
4. `kubectl exec ... env`로 컨테이너 안에 `GREETING`, `LOG_LEVEL` 환경변수가 실제로 주입된 것 확인
5. **핵심 실험 1**: ConfigMap의 `LOG_LEVEL`을 `debug → info`로 바꾸고 apply해도, 같은 Pod에서 다시 확인하면 **환경변수는 그대로 `debug`** — 환경변수는 컨테이너 시작 시점에 값이 고정된다는 것을 직접 확인
6. `kubectl rollout restart deployment/nginx-deployment`로 Pod를 강제 재생성 → 새 Pod에서는 `LOG_LEVEL=info`로 반영됨 확인. YAML 스펙을 하나도 안 바꿔도 `restartedAt` annotation으로 롤링 업데이트가 트리거된다는 것도 학습
7. **핵심 실험 2 (볼륨 마운트)**: Deployment에 `volumeMounts`/`volumes`로 ConfigMap을 `/etc/config`에 파일로 마운트 → apply(이때도 롤링 업데이트 발생)
   - ConfigMap 값을 다시 바꾸고(`info → debug-v2`) apply한 뒤, **Pod를 재생성하지 않고 1분 정도만 기다렸다가** 같은 Pod에서 `cat /etc/config/LOG_LEVEL` → 파일 내용이 자동으로 갱신됨을 확인 (kubelet의 주기적 동기화)
   - 환경변수 방식(재생성 필요) vs 볼륨 마운트 방식(자동 동기화)의 차이를 실습으로 직접 대조
8. `kubectl delete -f`로 Deployment/Service/ConfigMap 전부 정리 완료

## 배운 것 요약
- ConfigMap은 설정을 이미지와 분리해서 관리하게 해주며, 환경변수/볼륨 마운트 두 가지 방식으로 Pod에 주입 가능
- **환경변수 주입은 Pod가 뜰 때 값이 고정**됨 — ConfigMap을 바꿔도 재생성 전까지 반영 안 됨
- **볼륨 마운트는 kubelet이 주기적으로 파일을 동기화**해서 Pod 재생성 없이도 내용이 갱신됨 (단, 앱이 그 파일을 다시 읽는 로직이 있어야 실제 동작에 반영됨)
- `kubectl rollout restart`는 스펙을 안 바꿔도 `restartedAt` annotation으로 강제 롤링 업데이트를 일으키는 명령어
- Pod 템플릿(컨테이너 정의)이 바뀌면 이미지 버전과 무관하게 항상 롤링 업데이트가 발생함