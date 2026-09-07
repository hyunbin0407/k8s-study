# 실습 15 가이드 — Prometheus + Grafana 모니터링 스택 (직접 해보기)

이 가이드를 보면서 터미널에 직접 명령어를 입력해보세요. 막히면 결과를 저한테 붙여넣어 주시면 같이 확인해드릴게요.

이번 실습은 처음으로 **남이 만든 공식 Helm Chart**를 설치해봅니다. 우리 `webapp` 프로젝트는 건드리지 않고, 완전히 별개의 `monitoring` Namespace에 관찰성 도구를 올립니다.

## 준비

```bash
cd ~/Workspace/k8s-study
kubectl get pods -n webapp   # postgres-0, adminer 4개 살아있는지 확인
```

## Step 1. Helm Repository 추가

지금까지는 우리가 직접 만든 Chart(`helm/webapp-chart`)만 썼는데, 이번엔 Helm의 "Repository"(Chart 저장소) 개념을 처음 씁니다.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo kube-prometheus-stack
```

**확인할 것**: `kube-prometheus-stack`이라는 Chart가 검색 결과에 나오는지. 이게 우리가 만든 것과 달리, 커뮤니티가 관리하는 공식 Chart입니다.

## Step 2. kube-prometheus-stack 설치

```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

**참고**: 이번 설치는 지금까지 중 가장 무겁습니다. Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics까지 여러 컴포넌트의 이미지를 받아오느라 **3~5분 정도 걸릴 수 있습니다.** 느긋하게 기다려주세요.

```bash
kubectl get pods -n monitoring -w
```
전부(또는 대부분) `Running`이 될 때까지 지켜본 후 `Ctrl+C`로 빠져나오세요.

```bash
kubectl get pods -n monitoring
```

## Step 3. Grafana 로그인 정보 확인

Grafana의 관리자 비밀번호는 설치 시 자동 생성되어 Secret에 저장됩니다.

```bash
kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d
echo
```
출력된 비밀번호를 기록해두세요. 사용자 이름은 기본값 `admin`입니다.

## Step 4. Grafana 접속하기

이번엔 Ingress를 새로 안 만들고, 1회차에서 배운 `port-forward`로 간단히 접속합니다.

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```
이 명령은 터미널을 점유합니다. 새 터미널 탭을 열어서 브라우저로 `http://localhost:3000`에 접속하세요. Step 3에서 확인한 `admin`/비밀번호로 로그인합니다.

## Step 5. 미리 만들어진 대시보드 둘러보기

로그인 후 왼쪽 메뉴에서 **Dashboards**로 들어가면, `kube-prometheus-stack`이 자동으로 설치해준 대시보드 여러 개가 보입니다.

`Kubernetes / Compute Resources / Namespace (Pods)`라는 대시보드를 열어보세요. 상단의 `namespace` 드롭다운에서 **`webapp`**을 선택하세요.

**확인할 것**: postgres-0, adminer Pod들의 CPU/메모리 사용량이 그래프로 나오는지. 지금은 다들 놀고 있으니 낮은 수준일 겁니다 — 이게 기준선(baseline)입니다.

## Step 6. HPA를 다시 걸어두기

12회차에서 만들어뒀던 HPA 파일을 재사용합니다.

```bash
kubectl apply -f manifests/project/14-adminer-hpa.yaml
kubectl get hpa -n webapp
```

## Step 7. 부하를 걸면서 Grafana에서 실시간으로 지켜보기 (핵심)

**터미널 A**: Grafana 대시보드를 열어둔 브라우저 (Step 5의 그 화면, `webapp` 네임스페이스 선택된 상태)

**터미널 B**: HPA 상태 관찰
```bash
kubectl get hpa -n webapp -w
```

**터미널 C**: 부하 생성 (12회차와 동일한 방식)
```bash
kubectl run load-generator -n webapp --image=busybox --restart=Never -- \
  sh -c "for i in 1 2 3 4 5 6 7 8; do (while true; do wget -q -O- http://adminer-service:8080/ > /dev/null; done) & done; sleep 300"
```

부하가 시작되면 **브라우저의 Grafana 대시보드를 새로고침**(또는 자동 새로고침 설정, 우측 상단 시계 아이콘 옆)하면서 지켜보세요.

**확인할 것**:
- Grafana 그래프에서 adminer Pod들의 CPU 사용량 선이 눈에 띄게 올라가는지
- 터미널 B에서 HPA의 `TARGETS`가 올라가고 `REPLICAS`가 자동으로 늘어나는지
- 늘어난 새 Pod들도 Grafana 그래프에 새로운 선으로 나타나는지

같은 사건(부하 발생 → 오토스케일링)을 **텍스트(kubectl)**와 **그래프(Grafana)** 양쪽에서 동시에 확인하는 게 이번 실습의 핵심입니다.

## Step 8. 부하 제거 후 그래프도 같이 내려가는지 확인

```bash
kubectl delete pod load-generator -n webapp
```
Grafana 대시보드에서 CPU 사용량 선이 점점 내려가고, 몇 분 후 HPA도 Pod 개수를 줄이는 것까지 계속 지켜보세요.

## Step 9. 정리

HPA만 다시 정리합니다 (12회차와 동일):
```bash
kubectl delete -f manifests/project/14-adminer-hpa.yaml
kubectl scale deployment/adminer-deployment --replicas=4 -n webapp
```

port-forward 중이던 터미널은 `Ctrl+C`로 종료하세요.

모니터링 스택 자체는 앞으로도 계속 유용하게 쓸 수 있으니 **일단 남겨두는 것을 추천**합니다. 클러스터 리소스를 아끼고 싶으면 지워도 됩니다 (선택):
```bash
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

## 막혔을 때 자가진단 순서
1. `kubectl get pods -n monitoring` — 일부 Pod가 계속 `Pending`이면 `kubectl describe pod <이름> -n monitoring`으로 리소스 부족 여부 확인 (Docker Desktop 메모리 할당량이 낮으면 발생 가능 — Docker Desktop 설정에서 메모리 늘리기 고려)
2. Grafana 로그인이 안 되면 `kubectl get secret -n monitoring monitoring-grafana -o yaml`로 Secret이 실제로 있는지 재확인
3. 대시보드에 데이터가 안 보이면 좌측 메뉴 Connections → Data sources에서 Prometheus가 정상 연결(`Test` 버튼) 상태인지 확인
4. 그래프가 안 올라가면 `kubectl top pods -n webapp`으로 실제 부하가 걸리고 있는지 먼저 확인

---
막히는 부분 있으면 명령어 결과 그대로 붙여넣어 주세요. 같이 원인 찾아드릴게요.
