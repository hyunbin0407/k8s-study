#!/bin/bash
# kubeadm 클러스터 구성을 위한 노드 사전 준비 스크립트
# control-plane, worker 노드 양쪽에 동일하게 실행합니다.
set -euo pipefail

echo "=== 1. swap 비활성화 ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "=== 2. 커널 모듈 로드 (overlay, br_netfilter) ==="
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "=== 3. 네트워킹 sysctl 설정 ==="
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "=== 4. containerd 설치 및 설정 ==="
sudo apt-get update
# conntrack: kube-proxy 필수, socat: kubectl port-forward 필수 (kubeadm preflight가 요구)
sudo apt-get install -y containerd conntrack socat
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== 5. kubeadm / kubelet / kubectl 설치 ==="
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "=== 설치 완료. 버전 확인 ==="
kubeadm version
kubelet --version
kubectl version --client
