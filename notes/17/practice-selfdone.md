# 실습 17 — 직접 완주! 클러스터 직접 구성 1단계 (VM 준비 + 사전 요구사항)

가이드: [practice-guide.md](practice-guide.md) · 전체 계획: [design.md](design.md)

## 진행 내용

1. **VM 기동** — 이전 세션에서 `multipass launch`가 macOS vmnet 권한 문제로 실패했었으나, Mac 재부팅 후 `k8s-control` / `k8s-worker` 두 대 정상 생성. 이번 세션에서는 `k8s-control`이 Stopped 상태여서 `multipass start k8s-control`로 기동.
   - `k8s-control`: 192.168.252.6
   - `k8s-worker`: 192.168.252.5
   - `linuxmaster`: 계속 Stopped (안 건드림)
2. **Step 2** — `multipass shell k8s-control`로 접속, `cat /etc/os-release`(Ubuntu 22.04.5 LTS) / `whoami`(ubuntu) 확인 후 `exit`.
3. **Step 3** — `multipass transfer infra/prepare-node.sh <VM>:/home/ubuntu/prepare-node.sh`로 두 VM에 사전 준비 스크립트 복사 (성공 시 출력 없음).
4. **Step 4~5** — `multipass exec <VM> -- sudo bash /home/ubuntu/prepare-node.sh`를 control, worker 순서로 실행. 두 대 모두 5단계 전부 통과:
   1. swap 비활성화 (`swapoff -a` + `/etc/fstab` 주석 처리)
   2. 커널 모듈 로드 (`overlay`, `br_netfilter`)
   3. sysctl 설정 — `bridge-nf-call-iptables`/`bridge-nf-call-ip6tables`/`ip_forward` = 1
   4. containerd 설치 (Ubuntu 저장소, 2.2.1) + `config.toml` 생성 + `SystemdCgroup = true` 패치 + restart/enable
   5. 쿠버네티스 apt 저장소(`pkgs.k8s.io` v1.31) 등록 후 `kubelet`/`kubeadm`/`kubectl` 설치 + `apt-mark hold`
5. **Step 6 — 검증** (두 노드 모두 동일):
   - `kubeadm version` → **v1.31.14** (linux/arm64)
   - `kubectl version --client` → v1.31.14
   - `systemctl is-active containerd` → `active`
   - `grep SystemdCgroup /etc/containerd/config.toml` → `SystemdCgroup = true`

## 겪은 것 / 배운 것

- **이전 세션의 vmnet 권한 문제는 Mac 재부팅으로 해결됨.** Multipass가 macOS 네트워킹 확장 승인을 재부팅 시점에 받은 것으로 추정.
- 스크립트 3단계에서 `sysctl: setting key "net.ipv4.conf.all.accept_source_route": Invalid argument` 등 경고가 떴지만 **무시해도 됨** — 이건 Ubuntu 기본 `50-default.conf`가 이 커널에 없는 키를 건드려서 나는 것이고, 우리가 넣은 `k8s.conf`의 키 3개는 마지막에 `= 1`로 정상 적용됨.
- containerd가 Docker 저장소가 아니라 **Ubuntu 기본 저장소의 2.2.1 버전**으로 설치됨. `containerd config default`로 만든 기본 설정에서도 `sed`로 `SystemdCgroup = true` 치환이 정상 동작 — 다음 회차 `kubeadm init` 시 cgroup 드라이버(systemd) 불일치 문제 없을 것으로 예상.
- 아직 **클러스터는 존재하지 않음.** 도구만 설치한 상태. 다음 회차(18)에서 `k8s-control`에 `kubeadm init` 실행 예정.

## 현재 상태 (2026-09-10 기준)

- Multipass VM 2대(`k8s-control`, `k8s-worker`) Running, 사전 요구사항 + 쿠버네티스 도구(v1.31.14) 설치 완료. 다음 세션까지 Stopped로 꺼둬도 무방.
- 기존 Docker Desktop 클러스터(`webapp`/`monitoring`/`argocd`)는 전혀 안 건드림 — 완전히 별개.
