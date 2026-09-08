# 실습 16 가이드 — GitOps (ArgoCD로 자동 배포, 직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

이번 실습은 우리 `k8s-study` GitHub 레포의 `helm/webapp-chart`를 ArgoCD가 감시하게 만들어서, **git push만으로 클러스터가 자동으로 바뀌는 것**을 확인합니다. 기존 `webapp` 프로젝트는 건드리지 않고, 완전히 새로운 `webapp-gitops` Namespace에 배포합니다.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl get pods -n webapp   # 기존 프로젝트 살아있는지 확인
git remote -v                # 우리 레포 주소 확인 (다음 단계에서 씀)
```

## Step 1. ArgoCD 설치 (Helm으로)

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace
```

이번에도 이미지를 여러 개 받아오느라 몇 분 걸릴 수 있습니다.

```bash
kubectl get pods -n argocd -w
```
대부분 `Running`이 되면 `Ctrl+C`.

## Step 2. ArgoCD 관리자 비밀번호 확인

15회차 Grafana 때와 똑같은 패턴입니다 — 설치 시 자동 생성된 비밀번호가 Secret에 있습니다.

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```
출력된 비밀번호를 기록해두세요. 사용자 이름은 `admin`입니다.

## Step 3. ArgoCD 웹 UI 접속

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```
새 터미널 탭에서 브라우저로 `https://localhost:8080`에 접속하세요.

**참고**: ArgoCD는 자체 서명 인증서를 쓰기 때문에 브라우저가 "안전하지 않은 사이트" 경고를 띄울 겁니다. `고급` → `안전하지 않음(계속 진행)`을 눌러서 넘어가세요 — 우리끼리만 쓰는 로컬 환경이라 문제없습니다.

`admin` / Step 2에서 확인한 비밀번호로 로그인하세요.

## Step 4. Application 만들기 — 우리 레포를 감시하게 설정

`git remote -v`로 확인했던 우리 레포 주소를 사용합니다.

```bash
nano manifests/argocd-webapp-application.yaml
```
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/hyunbin0407/k8s-study.git
    path: helm/webapp-chart
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: webapp-gitops
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

**체크 포인트**: `repoURL`이 본인의 실제 GitHub 레포 주소와 일치하는지 확인하세요. `path`는 감시할 폴더(우리 Helm Chart 위치), `destination.namespace`는 새로 만들 `webapp-gitops`입니다.

```bash
kubectl apply -f manifests/argocd-webapp-application.yaml
```

## Step 5. 자동 배포 확인하기 (핵심)

ArgoCD UI에서 `webapp`이라는 Application 카드가 나타날 겁니다. 몇 초~1분 안에 자동으로 동기화(Sync)되면서 초록색 체크 표시들이 뜨는지 지켜보세요.

터미널에서도 확인:
```bash
kubectl get pods -n webapp-gitops
kubectl get application webapp -n argocd
```

**확인할 것**: `webapp-gitops` Namespace에 postgres, adminer, Ingress 등이 **우리가 `kubectl`이나 `helm`을 한 번도 직접 실행하지 않았는데도** 전부 자동으로 배포됐는지. ArgoCD가 대신 `helm template` + `kubectl apply`를 해준 것입니다.

## Step 6. Git push만으로 클러스터가 바뀌는 것 확인 (진짜 핵심)

`helm/webapp-chart/values.yaml`의 값을 하나 바꿔서 git에 올려봅니다.

```bash
nano helm/webapp-chart/values.yaml
```
`adminer.replicas`를 `4`에서 `2`로 바꾸세요.

```bash
git add helm/webapp-chart/values.yaml
git commit -m "Reduce adminer replicas to 2 for GitOps demo"
git push
```

**이제 `kubectl`이나 `helm` 명령을 아무것도 실행하지 마세요.** ArgoCD UI를 지켜보거나, 터미널에서 반복 확인해보세요:

```bash
kubectl get pods -n webapp-gitops -l app=adminer
```

ArgoCD의 기본 폴링 주기(약 3분) 안에 자동으로 감지해서 Pod 개수가 4개 → 2개로 바뀌는지 확인하세요. 더 빨리 보고 싶으면 ArgoCD UI에서 해당 Application을 열고 우측 상단의 **REFRESH** 버튼을 눌러 즉시 확인을 트리거할 수 있습니다.

## Step 7. Self-Heal 확인 — 수동으로 건드려도 자동 복구되는지 (핵심)

이번엔 반대로, 클러스터를 직접 수동으로 건드려봅니다.

```bash
kubectl scale deployment/adminer-deployment -n webapp-gitops --replicas=5
kubectl get pods -n webapp-gitops -l app=adminer
```
잠깐은 5개로 늘어난 걸 보실 수 있을 겁니다. 하지만 몇 초~수십 초 안에:

```bash
kubectl get pods -n webapp-gitops -l app=adminer
```
**확인할 것**: ArgoCD가 "Git에는 2개로 적혀있는데 실제로는 5개네? 되돌려야지" 하고 자동으로 다시 2개로 되돌리는지. `syncPolicy.automated.selfHeal: true`가 정확히 이 동작을 만든 것입니다 — `kubectl scale`로 직접 명령해도 GitOps 앞에서는 무력화됩니다.

## Step 8. 정리

이번 실습용 리소스만 정리합니다 (기존 `webapp`, `monitoring`은 그대로 둡니다).

```bash
kubectl delete -f manifests/argocd-webapp-application.yaml
kubectl delete namespace webapp-gitops
```

ArgoCD 자체는 계속 유용하니 남겨두는 것을 추천하지만, 클러스터 리소스가 부담되면 지워도 됩니다 (선택):
```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

마지막으로 `helm/webapp-chart/values.yaml`의 `adminer.replicas`를 다시 `4`로 되돌리고 git에 커밋해두세요 (다음에 헷갈리지 않게):
```bash
nano helm/webapp-chart/values.yaml
git add helm/webapp-chart/values.yaml
git commit -m "Restore adminer replicas to 4 after GitOps demo"
git push
```

## 막혔을 때 자가진단 순서
1. `kubectl get application webapp -n argocd -o yaml`의 `status` 필드에서 동기화 실패 이유 확인
2. Application이 `Unknown`/`OutOfSync`로 계속 멈춰있으면 `repoURL`/`path`/`targetRevision`이 정확한지(오타, 브랜치명) 재확인
3. `kubectl get pods -n argocd`로 `argocd-repo-server`가 `Running`인지 확인 (이 Pod가 실제로 Git을 clone하는 역할)
4. Step 6에서 반영이 안 되면 브라우저 캐시나 커밋이 실제로 push됐는지(`git log origin/main`) 확인
5. YAML 들여쓰기 문제면 `kubectl apply --dry-run=client -f <파일>`로 사전 검증

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
