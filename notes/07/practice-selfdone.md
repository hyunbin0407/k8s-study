# 실습 07 — 직접 완주! PersistentVolume

가이드: [practice-guide.md](practice-guide.md)

## 진행 내용

1. `manifests/06-nginx-pvc.yaml` 작성(`ReadWriteOnce`, `1Gi`) → apply, `STATUS: Pending` 확인 (`WaitForFirstConsumer`라 아직 아무 Pod도 안 써서 정상)
2. `manifests/01-nginx-deployment.yaml`에 PVC를 `/usr/share/nginx/html`에 마운트, `replicas`를 3→1로 임시 축소
   - 1차 시도에서 nano 자동 들여쓰기로 탭 문자 에러 발생 + `volumeMounts`에 `html-storage` 항목 누락, 둘 다 확인 후 수정해서 재적용 성공
   - apply 후 `configmap "nginx-config" not found`로 Pod가 `ContainerCreating`에 멈춤 → 가이드의 준비 단계에 ConfigMap/Secret 적용 안내가 빠져있던 것을 발견, `03-nginx-configmap.yaml`/`04-nginx-secret.yaml` 적용해서 해결 (가이드 문서도 수정)
   - PVC가 `Pending → Bound`로 전환, `kubectl get pv`로 `local-path-provisioner`가 자동 생성한 PV(`pvc-a8fff06e-...`) 확인
3. `kubectl exec`로 마운트된 경로에 커스텀 `index.html`(`Hello from PersistentVolume`) 작성, `cat`과 Service 경유 `curl` 둘 다로 확인
4. **핵심 실험**: Deployment 전체를 삭제했다가 재생성(Step 4의 Pod 삭제보다 더 강한 버전으로 진행)
   - Deployment/Pod가 사라진 동안에도 PVC는 `Bound` 상태 그대로, 같은 PV(`pvc-a8fff06e-...`)를 유지
   - 재생성된 새 Pod에서 `cat`으로 확인해보니 `Hello from PersistentVolume`이 그대로 남아있음 — 데이터가 Pod/Deployment와 무관하게 PVC에만 종속된다는 것을 확인
5. PVC를 삭제하니 연결되어 있던 PV도 함께 자동 삭제되는 것 확인 (`kubectl get pv` → `No resources found`) — `ReclaimPolicy: Delete` 정책 때문
6. 정리: 남아있던 ConfigMap/Secret 삭제, `manifests/01-nginx-deployment.yaml`을 원래 상태(`replicas: 3`, PVC 볼륨 제거)로 복원

## 배운 것 요약
- PVC는 `WaitForFirstConsumer` StorageClass에서는 실제 소비하는 Pod가 생기기 전까지 `Pending` 상태로 대기 — 정상 동작
- `local-path-provisioner`가 PVC 요청에 맞춰 PV를 자동 생성(동적 프로비저닝)
- 데이터의 생명주기는 Pod나 Deployment가 아니라 **PVC**에 종속됨 — Pod/Deployment를 지웠다 다시 만들어도 데이터는 유지됨
- PVC를 지우면 `ReclaimPolicy`(기본값 `Delete`)에 따라 PV와 실제 데이터까지 함께 삭제될 수 있음
- 여러 리소스가 서로 참조하는 스택(Deployment가 ConfigMap/Secret을 참조)에서는 의존성 순서대로 먼저 적용해야 한다는 것을 다시 한번 실전에서 확인 (실습 가이드 자체의 누락도 발견해서 고침)
