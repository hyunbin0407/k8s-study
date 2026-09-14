# 실습 20 — 직접 완주! Worker 합류 (`kubeadm join`)

가이드: [practice-guide.md](practice-guide.md) · 개념: [../concepts.md](../concepts.md) "`kubeadm join`이 실제로 하는 일"

## 진행 내용

1. **준비 확인**:
   - `k8s-worker`: `which conntrack socat` → 둘 다 경로 나옴(`/usr/sbin/conntrack`, `/usr/bin/socat`) — 17회차 구버전 스크립트였지만 실제로는 누락 안 됐던 것으로 확인, 재설치 불필요.
   - `k8s-control`: `which conntrack socat`도 확인(둘 다 있음), `kubectl get nodes`/`kubectl get pods -n kube-system`으로 19회차 마지막 상태(`Ready`, 전부 `Running`) 그대로임을 확인.
2. **Step 1: join 명령 재발급** — `sudo kubeadm token create --print-join-command`로 새 토큰 발급. CA 해시(`639ec3af...`)는 18회차와 완전히 동일(클러스터 CA가 안 바뀌었으니 정상).
3. **Step 2: join 실행에서 실수 → 복구**:
   - **1차 시도를 `k8s-control` 터미널에서 실행**(워커가 아니라 컨트롤 플레인 자기 자신에 join 시도) → preflight에서 `kubelet.conf already exists` / `Port 10250 is in use` / `ca.crt already exists` 3건 에러로 실패. preflight 단계에서 막혀 아무 것도 변경되기 전에 실패한 것이라 `k8s-control`에는 영향 없음(재확인함).
   - **`multipass shell k8s-worker`로 올바른 터미널로 전환** 후 동일 명령 재실행 → `This node has joined the cluster.` 성공. TLS Bootstrap 로그(CSR 전송→응답 수신) 확인.
4. **Step 3: 검증** — 전부 예상대로 통과:
   - `kubectl get nodes` → `k8s-control`(`Ready`, control-plane) + `k8s-worker`(`Ready`, 빈 ROLES) 2노드. `k8s-worker`는 join 후 79초 만에 `Ready` 전환(CNI DaemonSet이 빠르게 뜸).
   - `kubectl get nodes -o wide` → `INTERNAL-IP`가 각각 `192.168.252.6`(control) / `192.168.252.5`(worker), 둘 다 `v1.31.14`, `containerd://2.2.1`로 버전 일치.
   - `kubectl get pods -n kube-system -o wide` → `kube-proxy`/`calico-node`가 `k8s-worker`용으로 각각 하나씩(`kube-proxy-6nq7z`, `calico-node-48jhk`) **자동으로** 새로 뜸 — 사용자가 직접 설치한 적 없는 DaemonSet 자동 확장을 실제로 확인.

## 겪은 실수 (다시 나올 수 있으니 참고)

- **`kubeadm join`을 어느 노드 터미널에서 실행하는지 헷갈리기 쉬움** — 창을 여러 개 띄워두면 프롬프트(`ubuntu@k8s-control:~$` vs `ubuntu@k8s-worker:~$`)를 안 보고 명령만 복붙하다 잘못된 노드에서 실행할 수 있음. 다행히 join은 preflight 검증이 먼저라 잘못 실행해도(이미 클러스터 멤버인 노드에 실행) 안전하게 실패함 — 하지만 실행 전에 프롬프트 확인하는 습관이 유효.

## 현재 상태 (2026-09-15 기준)

- **새 kubeadm 클러스터**: `k8s-control`(control-plane) + `k8s-worker` 2노드 모두 `Ready`. 컨트롤 플레인 5개 + kube-proxy 2개 + calico-node 2개 + calico-kube-controllers + CoreDNS 2개 전부 `Running`.
- **기존 Docker Desktop 클러스터**(`webapp`/`monitoring`/`argocd`): 안 건드림.
- 다음: 21회차 — 지금까지 배운 Deployment+Service를 이 클러스터에 재배포해서 Pod가 두 노드에 실제로 분산 스케줄되는 것까지 확인하며 클러스터 직접 구성 프로젝트 마무리.
