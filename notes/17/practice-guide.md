# 실습 17 가이드 — 1단계: VM 준비 + 사전 요구사항 설치

전체 계획: [design.md](design.md)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

이번 회차의 목표: Multipass VM 2대를 만들고, 각 VM에 컨테이너 런타임(containerd)과 쿠버네티스 도구(kubeadm/kubelet/kubectl)를 설치합니다. 아직 클러스터를 실제로 만들지는 않습니다 (그건 다음 회차).

## 준비

```bash
cd ~/Workspace/k8s-study
multipass list   # 기존 linuxmaster 외에 아무것도 없는지 확인
```

## Step 1. VM 2대 생성

```bash
multipass launch --name k8s-control --cpus 2 --memory 2G --disk 10G 22.04
multipass launch --name k8s-worker --cpus 2 --memory 2G --disk 10G 22.04
```
각각 이미지를 다운로드하고 부팅하느라 몇 분 걸릴 수 있습니다.

```bash
multipass list
```

**확인할 것**: `k8s-control`, `k8s-worker` 둘 다 `Running` 상태이고, 각자 다른 IP를 가지고 있는지. `linuxmaster`는 그대로 `Stopped`로 남아있어야 합니다 (안 건드림).

## Step 2. VM 안 살펴보기

```bash
multipass shell k8s-control
```
이러면 그 VM 안으로 SSH 접속됩니다. 평범한 Ubuntu 서버라는 걸 확인해보세요:
```bash
cat /etc/os-release
whoami
exit
```
`exit`로 다시 Mac 터미널로 돌아옵니다.

## Step 3. 사전 준비 스크립트를 VM에 전달하기

지금까지처럼 nano로 이 긴 스크립트를 직접 타이핑하면 실수하기 쉬워서, 이번엔 이미 레포에 준비해둔 스크립트(`infra/prepare-node.sh`)를 각 VM에 복사해서 실행하는 방식으로 진행합니다.

```bash
multipass transfer infra/prepare-node.sh k8s-control:/home/ubuntu/prepare-node.sh
multipass transfer infra/prepare-node.sh k8s-worker:/home/ubuntu/prepare-node.sh
```

## Step 4. 스크립트 내용 훑어보기

실행하기 전에, 무엇을 하는 스크립트인지 한번 읽어보세요.

```bash
cat infra/prepare-node.sh
```

**5단계로 구성되어 있습니다**:
1. swap 비활성화 — kubelet은 swap이 켜져 있으면 정상 동작하지 않음
2. 커널 모듈(`overlay`, `br_netfilter`) 로드 — 컨테이너 네트워킹에 필요
3. sysctl 네트워킹 설정 — Pod 간 브릿지 트래픽 처리, IP 포워딩 활성화
4. containerd 설치 및 설정 — 실제 컨테이너를 실행할 엔진 (cgroup 드라이버를 systemd로 맞춤 — kubelet과 맞춰야 함)
5. kubeadm/kubelet/kubectl 설치 — 공식 쿠버네티스 apt 저장소에서 받아옴

## Step 5. 스크립트 실행하기 (두 VM 모두)

```bash
multipass exec k8s-control -- sudo bash /home/ubuntu/prepare-node.sh
```
전부 완료될 때까지 몇 분 기다리세요. 마지막에 `kubeadm version`, `kubelet --version`, `kubectl version --client` 출력이 나오면 성공입니다.

같은 걸 worker에도 실행합니다:
```bash
multipass exec k8s-worker -- sudo bash /home/ubuntu/prepare-node.sh
```

## Step 6. 설치 결과 검증

```bash
multipass exec k8s-control -- kubeadm version
multipass exec k8s-worker -- kubeadm version
```
두 VM 모두 같은 버전이 나오는지 확인하세요.

```bash
multipass exec k8s-control -- systemctl is-active containerd
multipass exec k8s-worker -- systemctl is-active containerd
```
둘 다 `active`가 나오는지 확인하세요.

## 여기서 멈추는 이유

지금까지는 "도구만 설치"한 상태고, 아직 클러스터는 존재하지 않습니다. 다음 회차(18회차)에서 `k8s-control`에 `kubeadm init`을 실행해서 실제로 Control Plane을 부팅해볼 예정입니다.

## 막혔을 때 자가진단 순서
1. `multipass list`로 VM이 실제로 `Running`인지 확인
2. 스크립트 실행 중 에러가 나면 어느 단계(1~5)에서 멈췄는지 출력 확인
3. `apt-get update`가 실패하면 VM의 네트워크 연결 확인: `multipass exec k8s-control -- ping -c 3 8.8.8.8`
4. `containerd` 관련 에러면 `multipass exec k8s-control -- sudo systemctl status containerd`로 상세 로그 확인
5. kubeadm 저장소 관련 에러(GPG 키 등)면 `pkgs.k8s.io`가 요구하는 최신 URL 형식이 바뀌었을 수 있음 — 이 경우 알려주시면 같이 확인하겠습니다

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
