# 실습 19 — 직접 완주! CNI 설치 (Calico)

가이드: [practice-guide.md](practice-guide.md) · 개념: [../concepts.md](../concepts.md) "Calico 설치가 실제로 하는 일"

## 진행 내용

1. **준비 확인** — `multipass shell k8s-control` 접속 후 `kubectl get nodes`/`kubectl get pods -n kube-system`으로 18회차 마지막 상태(`k8s-control NotReady`, `coredns` 2개 `Pending`) 그대로임을 확인. 컨트롤 플레인 Pod들의 `RESTARTS 2 (10m ago)`는 VM stop/start로 인한 재시작 흔적일 뿐, 문제 아님.
2. **Step 1: 매니페스트 다운로드** — `curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/calico.yaml`로 315KB 파일 정상 다운로드(404 없음).
3. **Step 2: CIDR 수정** — `nano calico.yaml`로 `CALICO_IPV4POOL_CIDR` 수정.
   - **1차 시도에서 놓친 부분**: 주석(`# `)은 지웠지만 값을 `192.168.0.0/16` 그대로 안 바꾸고 저장 → `grep`으로 확인하다가 발견.
   - 다시 열어 값을 `10.244.0.0/16`으로 수정 후 재확인, 정상 반영됨.
4. **Step 3: 적용** — `kubectl apply -f calico.yaml`로 CRD 20여 개 + ServiceAccount/ClusterRole/ClusterRoleBinding + `calico-node` DaemonSet + `calico-kube-controllers` Deployment 전부 한 번에 생성.
5. **Step 4~5: 검증** — 전부 예상대로 통과:
   - `kubectl get nodes` → `k8s-control` **`Ready`**
   - `kubectl get pods -n kube-system` → 전부 `Running` (`calico-node`, `calico-kube-controllers` 포함, CoreDNS 2개도 `Running`으로 전환)
   - `kubectl get pods -n kube-system -o wide` → `calico-node`는 호스트 네트워크라 `192.168.252.6` 그대로, `calico-kube-controllers`(`10.244.175.3`)와 CoreDNS 2개(`10.244.175.2`, `10.244.175.1`)는 새 Pod 네트워크 대역 IP를 받음 — Calico가 실제로 IP를 할당하고 있다는 증거를 직접 확인.

## 겪은 실수 (다시 나올 수 있으니 참고)

- `nano`로 주석만 지우고 **값 자체를 바꾸는 걸 깜빡하기 쉬움** — 주석 해제와 값 치환은 별개 동작이라 둘 다 확인해야 함. `grep -A1 CALICO_IPV4POOL_CIDR calico.yaml`로 최종 값까지 확인하는 습관이 유효했음.

## 현재 상태 (2026-09-12 기준)

- **새 kubeadm 클러스터**: `k8s-control` 1노드 완전히 `Ready`. 컨트롤 플레인 5개 + kube-proxy + CoreDNS 2개 + calico-node + calico-kube-controllers 전부 `Running`. 아직 워커 노드는 클러스터에 없음(단일 노드).
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림.
- 다음: 20회차 — `k8s-worker`에 `conntrack`/`socat` 설치 확인 후 `kubeadm join`으로 합류. 부트스트랩 토큰이 24h 지났으면 `k8s-control`에서 `sudo kubeadm token create --print-join-command`로 재발급.
