# 클러스터 직접 구성 — 전체 계획

Multipass VM 2대(Ubuntu 22.04)로 kubeadm 기반 멀티노드 클러스터를 직접 만든다. 스케일이 커서 여러 회차에 걸쳐 진행.

## 구성

```
Multipass VM 2대
  ├─ k8s-control (control-plane, 2 CPU / 2GB / 10GB) → kubeadm init
  └─ k8s-worker  (worker,        2 CPU / 2GB / 10GB) → kubeadm join
```
기존에 있던 `linuxmaster` VM은 이번 실습과 무관 — 건드리지 않음.

## 단계별 계획

| 회차(예정) | 단계 | 내용 |
|---|---|---|
| 17 (이번) | VM 준비 + 사전 요구사항 | Multipass VM 2대 생성, swap 비활성화, 커널 모듈/sysctl 설정, containerd + kubeadm/kubelet/kubectl 설치 |
| 18 | Control Plane 구축 | `k8s-control`에서 `kubeadm init` 실행, kubeconfig 설정, 컨트롤 플레인 Pod 확인 |
| 19 | CNI 설치 | Calico 설치, 노드가 `Ready`로 바뀌는 것 확인 |
| 20 | Worker 합류 | `k8s-worker`에서 `kubeadm join`, 2노드 클러스터 완성 확인 |
| 21 | 검증 | 지금까지 배운 것(Deployment+Service) 재배포해서 실제로 동작하는지 확인, 노드별 Pod 분산 확인 |

## 참고
- 기존 Docker Desktop 클러스터(`webapp`/`monitoring`/`argocd` 프로젝트)는 전혀 건드리지 않음 — 완전히 별개의 새 클러스터
- `kubectl` 컨텍스트가 여러 개(Docker Desktop용 + 새 kubeadm 클러스터용) 생기므로, 헷갈리지 않게 `kubectl config get-contexts`로 항상 확인하는 습관 필요
