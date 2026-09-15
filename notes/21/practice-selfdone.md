# 실습 21 — 직접 완주! 검증 (클러스터 직접 구성 프로젝트 마무리)

가이드: [practice-guide.md](practice-guide.md) · 개념: [../concepts.md](../concepts.md) "Control Plane Taint"

## 진행 내용

1. **준비 + Taint 확인/제거**:
   - `kubectl get nodes` → `k8s-control`/`k8s-worker` 둘 다 `Ready` 확인.
   - `kubectl describe node k8s-control | grep -A3 Taints` → `node-role.kubernetes.io/control-plane:NoSchedule` 있음을 확인.
   - `kubectl taint nodes k8s-control node-role.kubernetes.io/control-plane:NoSchedule-`로 제거 → 재확인 시 `<none>`.
2. **Step 1: Namespace + Deployment + Service** — `cluster-verify` namespace 생성, `hello.yaml`(nginxdemos/hello, 6 replicas + ClusterIP Service `hello-svc`) 작성 후 `kubectl apply -f hello.yaml` → 둘 다 `created`.
3. **Step 2: 노드 분산 확인** — `kubectl get pods -n cluster-verify -o wide`로 확인:
   - `k8s-control` (`10.244.175.x` 대역): 2개
   - `k8s-worker` (`10.244.254.x` 대역): 4개
   - taint 제거 없이는 볼 수 없었을 결과 — 양쪽 노드에 최소 1개씩 스케줄된 것 확인.
4. **Step 3: Service를 통한 노드 간 통신 확인** — `kubectl run curl-test --rm -it --image=busybox:1.36 -n cluster-verify --restart=Never -- sh`로 접속 후 `hello-svc`에 8번 반복 요청.
   - 응답의 `Server address`가 요청마다 바뀌며 `10.244.175.x`(control)와 `10.244.254.x`(worker) **양쪽 대역 모두** 나옴 → Service가 두 노드에 걸친 Pod들에 실제로 트래픽을 분산하고, Calico의 노드 간 라우팅(IP-in-IP 터널링)이 정상 동작함을 실전으로 확인.
   - (`sh: ---: not found`는 터미널 붙여넣기 중 줄바꿈이 깨져서 난 표시일 뿐, 테스트 결과와 무관.)
5. **Step 4: 정리** — 사용자 요청으로 Claude가 대행:
   - taint는 복구하지 않고 제거된 상태로 유지(계속 이 클러스터로 실습할 것이라 워크로드가 양쪽 노드에 자유롭게 뜨도록).
   - `multipass exec k8s-control -- kubectl delete namespace cluster-verify`로 정리, `kubectl get namespaces`로 기본 4개만 남았음을 재확인.

## 배운 것 요약

- kubeadm이 기본으로 건 control-plane taint 때문에, 워커 1대짜리 랩 클러스터에서는 taint를 제거해야만 두 노드에 걸친 스케줄링을 실제로 관찰할 수 있었음.
- Service(ClusterIP)는 Pod가 어느 노드에 있든 상관없이 균일하게 트래픽을 라우팅 — Calico가 노드 간 Pod 네트워킹을 투명하게 해결해주고 있다는 것을 `Server address`가 매 요청 바뀌는 것으로 직접 확인.
- 17회차(VM 준비)부터 여기까지, Docker Desktop이 숨겨왔던 클러스터 구축의 전 과정(VM 프로비저닝 → containerd → kubeadm init → CNI → worker join → 실제 워크로드 검증)을 전부 손으로 완주.

## 현재 상태 (2026-09-15 기준)

- **kubeadm 클러스터**: `k8s-control`+`k8s-worker` 2노드 `Ready`. taint 없음(워크로드가 양쪽 어디든 뜰 수 있음). `cluster-verify` namespace는 정리되어 기본 4개 namespace만 남음.
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림, 계속 별개로 유지.
- **🎉 17~21회차 "클러스터 직접 구성" 프로젝트 완주** — `notes/17/design.md`에서 계획한 5단계 전부 완료.
