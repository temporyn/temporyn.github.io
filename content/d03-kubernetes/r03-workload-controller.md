
---

***index***

[1. 워크로드 controller란](#1-워크로드-controller란)  
[2. ReplicaSet](#2-replicaset)  
[3. controllerRef와 소유권 충돌 방지](#3-controllerref와-소유권-충돌-방지)  
[4. Deployment](#4-deployment)  
[5. Deployment ↔ ReplicaSet ↔ Pod](#5-deployment--replicaset--pod)  
[6. cascading delete: foreground·background·orphan](#6-cascading-delete-foregroundbackgroundorphan)  
[7. 업데이트 전략](#7-업데이트-전략)  
[8. Proportional scaling](#8-proportional-scaling)  
[9. 롤아웃과 롤백](#9-롤아웃과-롤백)  
[10. 스케일링](#10-스케일링)  
[11. 주요 필드 정리](#11-주요-필드-정리)  
[12. 실습: 생성·업데이트·롤백](#12-실습-생성업데이트롤백)  
[13. 실습: 스케일과 롤링 관찰](#13-실습-스케일과-롤링-관찰)  
[14. 참고 링크](#14-참고-링크)

---



# 1. 워크로드 controller란
---

Pod는 일회용이라([Pod](/kubernetes/pod/) 참고) 직접 만들면 죽었을 때 아무도 되살리지 않는다. **controller**는 "원하는 상태"를 선언받아 현재 상태를 거기에 맞춰 유지하는 컴포넌트다.

핵심은 **reconciliation loop**다. controller는 끊임없이 현재 상태와 목표 상태(spec)를 비교하고, 차이가 있으면 Pod를 만들거나 지워 좁힌다. "replicas: 3"을 선언하면 하나가 죽어 2개가 되는 순간 controller가 1개를 새로 만들어 3개로 되돌린다.

워크로드 controller는 여러 종류가 있고, 이 문서는 그중 가장 기본인 **ReplicaSet**과 그 위 계층 **Deployment**를 다룬다.

| controller | 용도 |
|:-----|:-----|
| **ReplicaSet** | Pod 복제본을 지정 개수로 유지(저수준). |
| **Deployment** | ReplicaSet을 관리하며 무중단 업데이트·롤백 제공. 무상태 앱의 표준. |
| StatefulSet · DaemonSet · Job · CronJob | 별도 문서에서 다룬다. |

계층 관계는 **Deployment → ReplicaSet → Pod**로, 상위가 하위를 만들고 소유한다.



# 2. ReplicaSet
---

지정한 개수의 Pod 복제본이 항상 실행되도록 유지한다. 세 필드로 이뤄진다.

| 필드 | 뜻 |
|:--|:--|
| `replicas` | 유지할 Pod 개수 |
| `selector` | 관리 대상 Pod를 고르는 label selector. `spec.template`의 label과 맞아야 한다 |
| `template` | 개수를 채울 때 찍어낼 Pod 명세([Pod](/kubernetes/pod/)의 `spec`과 동일) |

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web            # 이 label을 가진 Pod를 관리 대상으로 삼는다
  template:
    metadata:
      labels:
        app: web          # selector와 반드시 일치
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
```

ReplicaSet은 selector에 맞는 Pod를 label로 식별해 인수(acquire)한다. template과 무관하게 **이미 떠 있던 bare Pod라도 label이 맞으면 관리 대상으로 끌어간다**. 소유 관계는 각 Pod의 `ownerReferences`에 기록된다.

`selector`는 `apps/v1`에서 **immutable**이라 만든 뒤 바꿀 수 없다. 구형 **ReplicationController**[^rc]의 후신으로 set-based selector(`matchExpressions`)를 지원한다. 다만 실무에서 ReplicaSet을 직접 만들 일은 거의 없다 — 롤링 업데이트·롤백이 없어서, 이 기능을 얹은 **Deployment**로 다룬다.



# 3. controllerRef와 소유권 충돌 방지
---

여러 controller가 같은 Pod를 동시에 관리하겠다고 나서면 서로 충돌한다. 쿠버네티스는 `ownerReferences` 안에 `controller: true` 필드를 하나만 허용해 이를 막는다 — 한 오브젝트는 최대 하나의 "주요 controller"만 가질 수 있다. ReplicaSet이 selector로 bare Pod를 인수할 때도 이 필드를 자신으로 설정해, 다른 ReplicaSet이 같은 Pod를 동시에 가져가지 못하게 한다.

```yaml
# 인수된 Pod의 ownerReferences
ownerReferences:
  - apiVersion: apps/v1
    kind: ReplicaSet
    name: nginx-rs
    uid: <ReplicaSet의 UID>
    controller: true             # 이 ReplicaSet이 유일한 주요 소유자
    blockOwnerDeletion: true     # 6장의 foreground 삭제와 연동
```



# 4. Deployment
---

ReplicaSet 위에 얹혀 **선언형 업데이트**를 담당한다. 원하는 상태(이미지 버전·replicas 등)를 적어 `apply`하면, Deployment가 ReplicaSet을 만들고 조절해 그 상태로 수렴시킨다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

필드 구성은 ReplicaSet과 같고, 여기에 업데이트 방식(`strategy`)이 더해진다. Deployment가 직접 Pod를 만들지 않는다 — **ReplicaSet을 만들고, ReplicaSet이 Pod를 만든다.**



# 5. Deployment ↔ ReplicaSet ↔ Pod
---

```text
+------------------------------------------+
| Deployment (nginx)                       |
|   +----------------------------------+   |
|   | ReplicaSet (nginx-<hash>)        |   |
|   |   +-------+ +-------+ +-------+  |   |
|   |   | Pod   | | Pod   | | Pod   |  |   |
|   |   +-------+ +-------+ +-------+  |   |
|   +----------------------------------+   |
+------------------------------------------+
```

→ Deployment가 ReplicaSet 하나를, ReplicaSet이 Pod 여러 개를 소유한다.

Deployment는 template을 바꿀 때마다 **새 ReplicaSet**을 만든다. 각 ReplicaSet은 곧 하나의 리비전(revision)이다. 이들을 구분하려고 Deployment는 `spec.template`을 해싱한 **`pod-template-hash`** label을 ReplicaSet과 그 Pod에 자동으로 붙인다(이름의 `<hash>` 부분). 이 label은 손대지 않는다.

소유 관계는 `ownerReferences`로 연결된다. Deployment를 지우면 딸린 ReplicaSet과 Pod가 함께 정리된다(cascading delete) — 그 정리 방식은 다음 장에서 다룬다.



# 6. cascading delete: foreground·background·orphan
---

Deployment 삭제가 ReplicaSet·Pod를 함께 정리하는 방식은 세 가지로 고를 수 있다.

| 방식 | 동작 |
|:-----|:-----|
| Background(기본) | API에서 소유자를 즉시 삭제하고, garbage collector가 그 뒤로 자식들을 비동기로 정리 |
| Foreground | 소유자에 `foregroundDeletion` finalizer를 걸어 "삭제 중" 상태로 API에 남겨두고, `blockOwnerDeletion: true`인 자식이 모두 지워진 뒤에야 소유자를 실제로 지움 |
| Orphan | 자식은 그대로 살려두고 소유자만 지움. `ownerReferences`는 남지만 가리키는 대상이 없는 고아 상태가 됨 |

```bash
kubectl delete deployment nginx --cascade=orphan       # ReplicaSet·Pod는 살아남음
kubectl delete deployment nginx --cascade=foreground     # 자식이 다 지워질 때까지 대기
kubectl delete deployment nginx                          # 기본값: background
```



# 7. 업데이트 전략
---

`spec.strategy.type`으로 template이 바뀔 때 Pod를 교체하는 방식을 정한다.

| 전략 | 동작 | 다운타임 |
|:-----|:-----|:--------|
| **RollingUpdate** (기본) | 새 Pod를 조금씩 띄우고 옛 Pod를 조금씩 내려 점진 교체. | 없음 |
| **Recreate** | 옛 Pod를 **전부 내린 뒤** 새 Pod를 만든다. | 있음 |

RollingUpdate는 두 파라미터로 교체 속도를 조절한다(절대 수 또는 %, 기본 둘 다 **25%**).

| 파라미터 | 기본 | 뜻 |
|:---------|:----:|:---|
| `maxUnavailable` | 25% | 업데이트 중 목표 개수 대비 동시에 사용 불가능해도 되는 Pod 최대치. |
| `maxSurge` | 25% | 목표 개수를 초과해 추가로 띄울 수 있는 Pod 최대치. |

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
```

퍼센트를 정수로 바꿀 때 반올림 방향이 서로 다르다 — `maxUnavailable`은 내림(floor), `maxSurge`는 올림(ceil)이다. `replicas: 10`에 둘 다 25%라면 `maxUnavailable`은 2(10×0.25=2.5 → 내림), `maxSurge`는 3(10×0.25=2.5 → 올림)이 된다. 둘 다 가용성을 우선하는 방향이다 — 못 쓰는 Pod 수는 적게, 잠깐 초과해도 되는 여유는 넉넉히 잡는다.

**롤아웃은 `spec.template`이 바뀔 때만** 일어난다. 이미지·label 등 template 변경은 새 리비전을 만들지만, `replicas`만 바꾸는 스케일링은 롤아웃을 트리거하지 않는다.



# 8. Proportional scaling
---

롤링 업데이트가 진행 중일 때(새·옛 ReplicaSet이 동시에 존재하는 상태) `replicas`를 바꾸면, Deployment controller는 그 변화를 새 ReplicaSet과 옛 ReplicaSet에 **현재 비율대로 나눠** 반영한다 — 롤아웃이 끝날 때까지 기다렸다가 한쪽에만 스케일을 적용하지 않는다.

예를 들어 옛 RS 7 / 새 RS 3으로 롤아웃이 진행 중인데 `replicas`를 10에서 15로 올리면, 대략 7:3 비율을 유지한 채 옛 RS와 새 RS 양쪽에 나눠 추가한다.



# 9. 롤아웃과 롤백
---

template을 바꾸면(예: 이미지 교체) Deployment가 새 ReplicaSet을 만들어 스케일 업하고, 옛 ReplicaSet을 스케일 다운한다.

```bash
kubectl set image deployment/nginx nginx=nginx:1.28   # 이미지 교체 → 롤아웃
kubectl edit deployment/nginx                          # 또는 직접 편집
kubectl apply -f deploy.yaml                            # 또는 선언형 적용
```

진행 상황 확인과 롤백은 `kubectl rollout`으로 한다.

| 명령 | 동작 |
|:-----|:-----|
| `kubectl rollout status deployment/nginx` | 롤아웃 진행·완료 확인 |
| `kubectl rollout history deployment/nginx` | 리비전 이력 |
| `kubectl rollout undo deployment/nginx` | 직전 리비전으로 롤백(`--to-revision=N`으로 특정 리비전) |
| `kubectl rollout restart deployment/nginx` | 모든 Pod 순차 재시작(새 리비전 생성) |
| `kubectl rollout pause` / `resume` | 롤아웃 일시정지 / 재개 |

`revisionHistoryLimit`(기본 **10**) — 롤백용으로 보관하는 옛 ReplicaSet 개수.

`progressDeadlineSeconds`(기본 **600**) — 이 시간 동안 진전이 없으면 롤아웃을 실패로 표시(`Progressing=False`).

이력의 CHANGE-CAUSE 열은 `kubernetes.io/change-cause` annotation으로 남긴다(옛 `--record` 플래그는 deprecated).



# 10. 스케일링
---

`replicas`만 조절하는 작업이라 리비전을 만들지 않는다.

```bash
kubectl scale deployment/nginx --replicas=5
```

또는 매니페스트의 `spec.replicas`를 바꿔 `apply`한다. 부하에 따라 자동으로 개수를 조절하려면 HPA(오토스케일링)를 쓰는데, 이는 별도 문서에서 다룬다.



# 11. 주요 필드 정리
---

| 필드 | 기본 | 뜻 |
|:-----|:----:|:---|
| `replicas` | 1 | 유지할 Pod 개수 |
| `selector` | (필수) | 관리 대상 Pod label. **immutable** |
| `strategy.type` | RollingUpdate | 업데이트 방식 |
| `strategy.rollingUpdate.maxUnavailable` | 25% | 동시 불가용 허용치(내림) |
| `strategy.rollingUpdate.maxSurge` | 25% | 초과 생성 허용치(올림) |
| `minReadySeconds` | 0 | Pod가 available로 간주되기까지 최소 준비 시간 |
| `revisionHistoryLimit` | 10 | 보관할 옛 ReplicaSet 수 |
| `progressDeadlineSeconds` | 600 | 진전 없을 때 실패 판정 시간 |



# 12. 실습: 생성·업데이트·롤백
---

minikube 클러스터가 실행 중이어야 한다(`kubectl get nodes`).

`deploy.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

```bash
kubectl apply -f deploy.yaml
kubectl get deploy nginx           # READY 3/3 확인
kubectl get rs                     # Deployment가 만든 ReplicaSet(이름에 hash)
kubectl get pods --show-labels     # pod-template-hash label 확인

# Pod의 소유 관계 확인
kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.ownerReferences}'

# 이미지 교체 → 롤링 업데이트
kubectl set image deployment/nginx nginx=nginx:1.28
kubectl rollout status deployment/nginx    # 진행 확인
kubectl get rs                             # 새 RS로 전환, 옛 RS는 0개로

# 이력과 롤백
kubectl rollout history deployment/nginx
kubectl rollout undo deployment/nginx      # 직전 리비전으로 복귀
```

`kubectl get rs`로 옛 ReplicaSet이 `DESIRED 0`으로 남아 있는 것을 보면, 롤백은 이 옛 RS를 다시 스케일 업하는 방식임을 알 수 있다.



# 13. 실습: 스케일과 롤링 관찰
---

```bash
# 스케일 (리비전 안 생김 — rollout history 개수 그대로)
kubectl scale deployment/nginx --replicas=5
kubectl get pods -w                 # 2개 추가 생성 (Ctrl+C)

# 롤링 교체 과정 실시간 관찰
kubectl get rs -w &                 # 새 RS 증가·옛 RS 감소
kubectl set image deployment/nginx nginx=nginx:1.27

# cascading delete 방식 비교
kubectl delete -f deploy.yaml --cascade=orphan
kubectl get rs                       # ReplicaSet은 남아 있음(소유자 없는 고아)
kubectl delete rs -l app=web         # 남은 ReplicaSet 정리
```



# 14. 참고 링크
---

─ Deployment — <https://kubernetes.io/ko/docs/concepts/workloads/controllers/deployment/>  
─ ReplicaSet — <https://kubernetes.io/ko/docs/concepts/workloads/controllers/replicaset/>  
─ Garbage Collection — <https://kubernetes.io/docs/concepts/architecture/garbage-collection/>

[^rc]: ReplicationController. ReplicaSet 이전의 복제 controller로, equality-based selector만 지원한다. 현재는 ReplicaSet(과 그 위 Deployment)으로 대체됐다.
