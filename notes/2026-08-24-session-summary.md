# 2026-08-24 세션 요약

오늘 대화를 진행 순서대로 번호 매겨 정리. 다음 세션 시작 전에 이 파일부터 읽으면 이어서 진행하기 좋음.
(이전 세션 요약: [2026-08-23-session-summary.md](2026-08-23-session-summary.md))

## 오늘 한 일 순서

1. **지난 진행 상황 확인** — 저장소(notes/manifests)와 세션 요약을 다시 확인하고, 지금까지 배운 개념(쿠버네티스 개요/컨테이너/Pod/Deployment/Service)과 실습 01(nginx 배포) 완료 상태를 재확인. 다음 할 일 후보(롤링 업데이트/스케일링/ConfigMap·Secret/Namespace/Volume/Ingress) 정리해서 안내.

2. **"인프라 구성 실습은 아직 이르지 않냐" 질문** — 지금까지 배운 건 전부 "이미 만들어진 클러스터 위에 앱을 배포하는 법"이고, 클러스터 자체를 구성하는 것(리눅스/네트워킹/kubeadm/클라우드 매니지드 K8s 등)은 별도 지식이 필요해 아직 이르다고 답변. 예전에 concepts.md에서 매니지드 K8s/kubeadm 섹션을 삭제했던 판단이 맞았음을 재확인. → 당분간 "기존 클러스터 위 앱 운영 개념"을 계속 쌓는 방향으로 진행하기로 함.

3. **롤링 업데이트 개념 설명 요청** — 개념 설명 (새 ReplicaSet을 늘리고 기존 ReplicaSet을 줄이는 방식, `maxUnavailable`/`maxSurge`, 관련 명령어 `set image`/`rollout status`/`rollout history`/`rollout undo`). `notes/concepts.md`에 정리해서 커밋.

4. **실습 진행 요청 ("가이드로 안내해서 내가 해볼게")** — `notes/practice-02-guide.md` 작성, 커밋. 이후 사용자가 가이드를 보며 직접 실습 진행, 단계별로 결과를 붙여넣으면 확인하는 방식으로 진행:
   - **4-1.** 지난 실습에서 정리했던 nginx Deployment+Service 재배포 → 이미지 `latest → 1.25`로 변경, `rollout status` 정상 확인
   - **4-2.** 터미널 두 개로 `1.25 → 1.26` 업데이트를 `-w`로 실시간 관찰 → Pod가 **하나씩** `Pending → Running` 되고 나서야 기존 Pod 하나가 `Terminating`되는 순서 확인
   - **4-3.** 결과 검증 — 새 ReplicaSet 소속 Pod로 전부 교체, 이미지 `1.26`, replicas 3개 유지, 예전 ReplicaSet은 `DESIRED 0`으로 이력에 남는 것 확인
   - **4-4.** `kubectl rollout history`로 리비전 이력(1,2,3) 확인, `CHANGE-CAUSE` 기본값 `<none>` 확인
   - **4-5.** `kubectl rollout undo`로 `1.26 → 1.25` 롤백 성공, 리비전 번호가 되돌아가는 게 아니라 새 리비전(4)으로 추가되는 방식임을 확인
   - **4-6.** 존재하지 않는 이미지 태그(`this-tag-does-not-exist`)로 업데이트 시도 → 새 Pod `ImagePullBackOff` 대기 중에도 기존 정상 Pod 3개는 안 죽고 서비스 유지되는 것 확인 (롤링 업데이트 안전성 체감)
   - **4-7.** `rollout undo`로 재복구 — 이번엔 기존 Pod가 애초에 안 흔들려서 Pod 이름/AGE 그대로 유지된 채 복구됨
   - **4-8.** `kubectl delete -f`로 리소스 정리 완료

5. **완주 기록 저장** — `notes/2026-08-24-practice-02-selfdone.md` 작성, README/세션요약 갱신 후 커밋+푸시.

6. **다음 실습 제안** — 스케일링(`kubectl scale`)이 다음 추천 순서로 제시됨 (아직 미착수).

7. **"지금까지 대화한거 저장해줘" 요청** — 이 세션 요약 파일(`2026-08-24-session-summary.md`) 작성, README의 "다음에 여기부터" 항목을 이 파일로 갱신, 메모리 파일도 갱신 후 커밋+푸시.

8. **(현재) 이 요약을 번호순으로 재정리 요청** — 지금 이 문서를 대화 진행 순서 그대로 번호 매겨 다시 정리.

## 배운 개념: 롤링 업데이트 (Rolling Update)
`notes/concepts.md`에 정리됨. 요약: Deployment 이미지 변경 시 Pod를 순차 교체해 무중단 배포. 새 ReplicaSet↑ / 기존 ReplicaSet↓ 방식. `maxUnavailable`/`maxSurge`(기본 각 25%)로 속도·안전성 조절.

## 현재 상태 (2026-08-24 기준)
- 클러스터: Kubernetes 활성화, 리소스는 정리되어 비어있음
- GitHub 레포: `main` 브랜치에 오늘 내용 전부 커밋/푸시 완료

## 다음에 이어서 할 만한 것
- [ ] 스케일링 실습 (`kubectl scale`로 Pod 개수 조절) — 다음 추천 순서
- [ ] ConfigMap / Secret 개념
- [ ] Namespace 개념
- [ ] Volume / PersistentVolume 개념 (스토리지)
- [ ] Ingress 개념
- [ ] (보류) 클러스터 직접 구성 — 리눅스/네트워킹 기초 또는 매니지드 K8s(클라우드) 사용법부터, 그 다음 kubeadm 멀티노드 구축