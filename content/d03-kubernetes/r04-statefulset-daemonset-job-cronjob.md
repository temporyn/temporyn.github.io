
---

***index***

[1. StatefulSet이란](#1-statefulset이란)  
[2. 네트워크 identity: headless Service와 Pod DNS](#2-네트워크-identity-headless-service와-pod-dns)  
[3. storage: volumeClaimTemplates](#3-storage-volumeclaimtemplates)  
[4. 순서 보장: 배포·스케일링·종료](#4-순서-보장-배포스케일링종료)  
[5. podManagementPolicy: OrderedReady와 Parallel](#5-podmanagementpolicy-orderedready와-parallel)  
[6. update 전략: RollingUpdate·partition·maxUnavailable](#6-update-전략-rollingupdatepartitionmaxunavailable)  
[7. PVC 보존 정책](#7-pvc-보존-정책)  
[8. StatefulSet 주요 필드 정리](#8-statefulset-주요-필드-정리)  
[9. DaemonSet이란](#9-daemonset이란)  
[10. 스케줄링: nodeAffinity와 default scheduler](#10-스케줄링-nodeaffinity와-default-scheduler)  
[11. taint와 toleration](#11-taint와-toleration)  
[12. update 전략과 주요 필드](#12-update-전략과-주요-필드)  
[13. Job이란](#13-job이란)  
[14. completion mode와 병렬도](#14-completion-mode와-병렬도)  
[15. 실패 처리와 종료 제어](#15-실패-처리와-종료-제어)  
[16. CronJob이란: schedule과 concurrencyPolicy](#16-cronjob이란-schedule과-concurrencypolicy)  
[17. 놓친 스케줄과 이력 관리](#17-놓친-스케줄과-이력-관리)  
[18. 리소스 선택 기준](#18-리소스-선택-기준)  
[19. 실습: StatefulSet](#19-실습-statefulset)  
[20. 실습: DaemonSet](#20-실습-daemonset)  
[21. 실습: Job과 CronJob](#21-실습-job과-cronjob)  
[22. 디버깅](#22-디버깅)  
[23. 참고 링크](#23-참고-링크)

---



# 1. StatefulSet이란
---

[Deployment와 ReplicaSet](/kubernetes/workload-controller/)은 Pod를 서로 바꿔써도 되는(interchangeable) 존재로 다룬다. 어떤 복제본이 죽어도 새 이름의 새 Pod로 채우면 그만이다. **StatefulSet**은 이 가정을 깨고 각 Pod에 **sticky identity**를 부여한다 — 안정적인 network identity(이름·DNS), 안정적인 storage(PVC), 그리고 순서를 지키는 배포·스케일링·삭제 세 가지를 보장한다.

무상태 앱(어떤 복제본이 요청을 받아도 결과가 같은 웹 서버 등)은 여전히 Deployment를 쓴다. 각 인스턴스가 자신만의 데이터나 역할(리더/팔로워, 파티션 번호 등)을 가져야 하는 상태 저장 앱 — 분산 DB, 메시지 브로커, 분산 합의 시스템 — 에 StatefulSet을 쓴다.

| 보장 | 내용 |
|:--|:--|
| 안정적 network identity | Pod 이름과 DNS 이름이 재생성 후에도 그대로 유지된다. |
| 안정적 storage | 각 Pod가 자기 몫의 PVC에 계속 재결합된다. |
| 순서 | 배포·스케일링·삭제가 ordinal 순서대로 일어난다. |



# 2. 네트워크 identity: headless Service와 Pod DNS
---

StatefulSet의 Pod 이름은 `<statefulset 이름>-<ordinal>` 형태로 고정되고, ordinal은 기본적으로 0부터 N-1까지 채워진다(`replicas: 3`이면 `web-0`, `web-1`, `web-2`). 시작 ordinal을 0이 아닌 값으로 바꾸는 `.spec.ordinals.start` 필드는 v1.31에 stable이 됐다.

이 identity를 네트워크에서 실제로 쓸 수 있게 하는 것이 **headless Service**(`clusterIP: None`)다. StatefulSet 자신은 Service를 만들지 않으므로 `spec.serviceName`이 가리키는 headless Service를 사용자가 직접 만들어야 한다. Pod의 DNS 이름은 `<pod 이름>.<governing service 이름>.<namespace>.svc.cluster.local` 형태로 해석된다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None      # headless: virtual IP를 할당하지 않음
  selector:
    app: web
  ports:
    - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web      # 위 headless Service 이름과 일치해야 한다
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

이 설정에서 `web-0`의 DNS 이름은 `web-0.web.default.svc.cluster.local`이다. Pod가 죽고 같은 ordinal로 재생성돼도 이 이름은 그대로다. 갓 생성된 Pod의 DNS가 즉시 조회되지 않는 경우가 있는데, CoreDNS의 negative caching(기본 30초) 때문에 아직 없던 레코드가 잠깐 캐시에 남아 있을 수 있다.

이름 있는 port가 있으면 SRV record도 함께 생성된다. headless Service는 일반 Service와 달리 Pod 하나가 아니라 **각 Pod마다 개별 응답**을 반환한다(peer discovery에 필요한 방식). Service 자체의 상세 필드는 [Service](/kubernetes/service/) 참고.



# 3. storage: volumeClaimTemplates
---

`spec.volumeClaimTemplates`에 PVC 템플릿을 적으면, StatefulSet controller가 Pod마다 그 템플릿으로 PVC를 만든다. PVC 이름은 `<volumeClaimTemplate 이름>-<pod 이름>` 형태로 고정된다(예: `www-web-0`).

```yaml
spec:
  volumeClaimTemplates:
    - metadata:
        name: www
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

`storageClassName`을 지정하지 않으면 클러스터의 default StorageClass가 쓰인다. `web-0`이 죽어 재생성돼도 controller는 새 PVC를 만들지 않고 **이름이 같은 기존 PVC**(`www-web-0`)에 다시 결합한다 — Pod가 바뀌어도 데이터는 그대로 이어지는 이유가 이것이다.

data safety를 위해 기본 동작은 StatefulSet을 지우거나 scale-down해도 **PVC를 지우지 않는다**. 이 기본값을 세밀하게 조절하는 `persistentVolumeClaimRetentionPolicy` 필드는 Heading.7에서 다룬다.



# 4. 순서 보장: 배포·스케일링·종료
---

배포와 scale-up은 ordinal 오름차순(0 → N-1)으로 진행하며, 앞선 Pod가 Running 및 Ready(그리고 `minReadySeconds`가 지정돼 있으면 그 시간만큼 더) 상태가 되기 전에는 다음 ordinal의 Pod를 만들지 않는다.

삭제와 scale-down은 반대로 ordinal 내림차순(N-1 → 0)으로 진행하며, 뒤쪽(더 높은 ordinal) Pod가 완전히 종료되기 전에는 앞쪽 Pod를 종료하지 않는다.

`minReadySeconds`(기본 0, v1.25에 stable)는 Pod가 Ready 상태가 된 뒤에도 "available"로 인정되기까지 대기할 최소 시간이다. 짧게 뜨자마자 죽는 Pod를 정상으로 오판하지 않게 하는 안전장치다.

StatefulSet 자체를 삭제하는 동작은 이 종료 순서를 보장하지 않는다. Pod들이 순서대로 곱게 종료되길 원하면, 삭제하기 전에 먼저 `replicas: 0`으로 스케일다운해야 한다.



# 5. podManagementPolicy: OrderedReady와 Parallel
---

`spec.podManagementPolicy`는 Heading.4의 순서 보장을 지킬지 여부를 정한다.

| 값 | 동작 |
|:--|:--|
| **OrderedReady**(기본) | Heading.4에서 설명한 순서(생성은 오름차순 + 이전 Pod Ready 대기, 삭제는 내림차순 + 이전 Pod 완전 종료 대기)를 그대로 지킨다. |
| **Parallel** | 순서·대기 없이 모든 Pod를 동시에 생성·삭제한다. |

`Parallel`을 Heading.6의 rolling update `maxUnavailable`(1보다 큰 값)과 조합하면, 한 번에 `maxUnavailable`개까지 Pod를 동시에 재생성하는 "bursting" 동작이 가능하다. identity·storage는 여전히 보장되지만 순서 보장이 필요 없는 워크로드(예: 각 인스턴스가 독립적으로 초기화되는 캐시 클러스터)에서 시작 속도를 높이는 데 쓴다.



# 6. update 전략: RollingUpdate·partition·maxUnavailable
---

`spec.updateStrategy.type`은 `spec.template`이 바뀔 때 기존 Pod를 어떻게 교체할지 정한다.

| 값 | 동작 |
|:--|:--|
| **RollingUpdate**(기본) | ordinal 역순(N-1 → 0)으로 Pod를 하나씩 지우고 새 template으로 재생성한다. |
| **OnDelete** | 자동 교체하지 않는다. 사용자가 Pod를 직접 지워야 그 자리에 새 template의 Pod가 생긴다. |

**partition** — `rollingUpdate.partition`(기본 0)을 지정하면 ordinal이 이 값 **이상**인 Pod만 새 template으로 갱신되고, 이 값 **미만**인 Pod는 설령 삭제되더라도 이전 template으로 다시 만들어진다. `partition`을 `replicas`보다 크게 설정하면 template 변경이 전혀 전파되지 않아, canary 검증처럼 일부 Pod만 먼저 새 버전으로 올려 보는 용도로 쓸 수 있다.

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 2       # ordinal 2 이상만 갱신 (replicas: 3이면 web-2만)
```

**maxUnavailable** — `rollingUpdate.maxUnavailable`은 rolling update 중 동시에 불가용 상태여도 되는 Pod 수를 정한다. 이 필드는 **v1.36 기준 beta이며 기본적으로 비활성화**돼 있어, 활성화하지 않으면 `OrderedReady` 정책에서 한 번에 정확히 1개씩만 교체된다. 이 필드는 버전에 따라 상태가 흔들렸다 — v1.24부터 alpha(기본 비활성)로 존재하다 v1.35.0에서 beta·기본 **활성**으로 바뀌었으나, `Parallel` 조합에서 회귀(regression)가 발견돼 v1.35.4(및 이를 반영한 v1.36)에서 다시 beta·기본 **비활성**으로 되돌아갔다. 활성화하려면 kube-apiserver와 kube-controller-manager에 `MaxUnavailableStatefulSet` feature gate를 명시적으로 켜야 한다.

`OrderedReady` 정책에서 새 template의 Pod가 영구히 Ready 상태가 되지 못하면(깨진 이미지, 잘못된 설정 등) rollout이 그 지점에서 멈추고 **자동으로 복구되지 않는다** — template을 이전 버전으로 되돌려도 이미 멈춰 있는 Pod가 저절로 재시도되지 않는 known issue다. 복구하려면 문제의 Pod를 수동으로 지워야 한다.



# 7. PVC 보존 정책
---

`spec.persistentVolumeClaimRetentionPolicy`는 Heading.3에서 말한 "기본적으로 PVC를 지우지 않는다"는 동작을 세분화한다. v1.32에 stable이 됐다.

```yaml
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain    # StatefulSet 자체를 지울 때: Retain(기본) | Delete
    whenScaled: Retain     # scale-down으로 Pod가 줄 때:   Retain(기본) | Delete
```

`whenDeleted`는 StatefulSet object를 지울 때, `whenScaled`는 replicas를 줄여 Pod가 없어질 때 PVC를 어떻게 할지 각각 따로 정한다. 둘 다 기본값은 `Retain`(보존)이다. `Delete`로 바꾸면 해당 이벤트가 일어날 때 PVC에 소유자 참조가 붙어 함께 정리(garbage collection)된다.



# 8. StatefulSet 주요 필드 정리
---

| 필드 | 기본 | 뜻 |
|:--|:--:|:--|
| `serviceName` | (필수) | governing headless Service 이름 |
| `replicas` | 1 | 유지할 Pod 개수 |
| `podManagementPolicy` | OrderedReady | 순서 보장 여부 |
| `updateStrategy.type` | RollingUpdate | 업데이트 방식 |
| `updateStrategy.rollingUpdate.partition` | 0 | 이 ordinal 미만은 갱신 제외 |
| `updateStrategy.rollingUpdate.maxUnavailable` | 1(비활성 시) | 동시 불가용 허용치. beta, v1.36 기준 기본 비활성 |
| `minReadySeconds` | 0 | Ready 후 available로 간주되기까지 대기 시간 |
| `persistentVolumeClaimRetentionPolicy.whenDeleted`/`whenScaled` | Retain | PVC 삭제/보존 정책 |
| `ordinals.start` | 0 | 시작 ordinal |
| `revisionHistoryLimit` | 10 | 보관할 리비전 수(Deployment와 동일한 관례값) |



# 9. DaemonSet이란
---

**DaemonSet**은 클러스터의 모든(또는 조건에 맞는) 노드마다 Pod를 정확히 하나씩 유지한다. 로그 수집기, 노드 모니터링 에이전트, CNI 플러그인, 노드별 storage 데몬처럼 "이 노드가 존재하는 한 반드시 떠 있어야 하는" 워크로드에 쓴다.

노드가 클러스터에 새로 추가되면 DaemonSet controller가 그 노드에도 Pod를 만들고, 노드가 제거되면 그 노드의 Pod는 garbage collect된다. `replicas` 개념이 없다 — 개수는 노드 수에 따라 자동으로 정해진다.



# 10. 스케줄링: nodeAffinity와 default scheduler
---

현재 DaemonSet controller는 각 대상 Pod에 `spec.affinity.nodeAffinity`로 배치할 노드를 지정하고, 실제 배치(binding)는 **kube-scheduler**가 다른 Pod와 동일한 절차로 수행한다. `ScheduleDaemonSetPods` feature gate가 v1.17에 stable이 되면서 굳어진 방식이다. 그 이전(v1.11 이전 및 과도기)에는 DaemonSet controller가 `spec.nodeName`을 직접 채워 scheduler를 거치지 않고 노드에 Pod를 꽂아 넣었다 — 지금은 이 우회 경로가 없다.

`spec.template.spec.nodeSelector` 또는 `affinity`를 지정하면 조건에 맞는 노드에만 Pod가 생성된다. 둘 다 비워두면 모든 노드가 대상이다.

```yaml
spec:
  template:
    spec:
      nodeSelector:
        disktype: ssd     # 이 label을 가진 노드에만 Pod 생성
```



# 11. taint와 toleration
---

DaemonSet controller는 Pod template에 다음 toleration을 **자동으로** 추가한다.

| taint key | effect |
|:--|:--|
| `node.kubernetes.io/not-ready` | NoExecute |
| `node.kubernetes.io/unreachable` | NoExecute |
| `node.kubernetes.io/disk-pressure` | NoSchedule |
| `node.kubernetes.io/memory-pressure` | NoSchedule |
| `node.kubernetes.io/pid-pressure` | NoSchedule |
| `node.kubernetes.io/unschedulable` | NoSchedule |
| `node.kubernetes.io/network-unavailable` | NoSchedule (hostNetwork Pod에만) |

이 목록에 **`node-role.kubernetes.io/control-plane` taint는 들어 있지 않다.** control-plane 노드에도 DaemonSet Pod를 띄우려면 pod template에 해당 toleration을 수동으로 추가해야 한다.

```yaml
spec:
  template:
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
```

`unschedulable:NoSchedule`이 자동으로 포함돼 있으므로, `kubectl cordon`으로 노드를 스케줄 대상에서 뺀 뒤에도 그 노드의 기존 DaemonSet Pod는 축출되지 않고 남는다(cordon은 노드의 `spec.unschedulable`을 `true`로 표시하는 동작이며, DaemonSet은 이 표시를 자동으로 tolerate하기 때문이라는 것이 이 목록으로부터 나오는 추론이다. 실제 3노드 minikube 클러스터에서 `kubectl cordon`으로 확인한 결과, `unschedulable:NoSchedule` taint가 붙은 뒤에도 그 노드의 기존 DaemonSet Pod는 `Running` 상태를 유지했다).

minikube는 기본 설정에서 control-plane 노드에 별도 taint를 두지 않는다(`kubectl get node <control-plane 노드> -o jsonpath='{.spec.taints}'`가 비어 있음을 실제로 확인했다) — 그래서 minikube에서는 control-plane taint 관련 toleration 없이도 DaemonSet Pod가 control-plane 노드에 그대로 스케줄된다. control-plane taint가 실제로 걸려 있는 kubeadm 클러스터에서만 위 수동 toleration이 필요하다.



# 12. update 전략과 주요 필드
---

`spec.updateStrategy.type`은 Deployment·StatefulSet과 같은 두 값을 가진다.

| 값 | 동작 |
|:--|:--|
| **RollingUpdate**(기본) | 노드별 Pod를 순차적으로 지우고 새로 만든다. |
| **OnDelete** | 자동 교체하지 않는다(v1.5 이전 DaemonSet의 유일한 동작이었다). |

| 필드 | 기본 | 뜻 |
|:--|:--:|:--|
| `updateStrategy.rollingUpdate.maxUnavailable` | 1 | 동시 불가용 허용 Pod 수 |
| `updateStrategy.rollingUpdate.maxSurge` | 0 | 초과 생성 허용 Pod 수(`maxSurge` 필드 자체는 v1.25 stable) |
| `minReadySeconds` | 0 | Ready 후 available 간주까지 대기 시간 |

rollout이 멈추는 대표 원인은 두 가지다. 노드 자체의 리소스가 부족해 새 Pod가 스케줄되지 못하는 경우(이때 비-DaemonSet Pod를 정리해 자리를 만들 수 있지만, 이 정리는 PodDisruptionBudget을 존중하지 않는다는 점을 문서가 명시적으로 경고한다), 그리고 새 template 자체가 깨져 있어 새 Pod가 `CrashLoopBackOff`·`ImagePullBackOff`로 멈추는 경우다. `minReadySeconds`를 쓰는 경우 control plane과 노드 간 clock skew가 진행 상태 판정을 어긋나게 할 수 있다.



# 13. Job이란
---

**Job**은 실행하고 끝나는(run-to-completion) 워크로드다. Deployment·DaemonSet이 "항상 떠 있는 상태"를 유지하는 것과 달리, Job은 지정한 횟수만큼 Pod가 **성공적으로 종료**되면 그것으로 끝난다.

Job의 Pod template은 `restartPolicy`로 `Never` 또는 `OnFailure`만 허용한다(`Always`나 미지정은 API validation에서 거부된다). 공식 문서는 이 제약의 이유를 명시적으로 설명하지 않는다 — Job이 완료 횟수를 자체적으로 추적하는데, kubelet의 `Always` 재시작 루프가 그 추적과 충돌하기 때문이라는 것은 합리적인 추론이지 공식 진술은 아니다.



# 14. completion mode와 병렬도
---

`spec.completionMode`는 `NonIndexed`(기본)와 `Indexed`(v1.24 stable) 중 하나다. `Indexed`는 각 Pod에 `0`부터 `completions-1`까지 고유한 완료 index를 부여해, Pod마다 서로 다른 작업 조각을 처리하게 한다.

`completions`·`parallelism` 조합으로 세 가지 실행 패턴이 나온다.

| 패턴 | 설정 | 동작 |
|:--|:--|:--|
| non-parallel | 둘 다 미지정(각각 기본 1) | Pod 하나가 성공하면 끝 |
| fixed completion count | `completions` 지정, `parallelism`은 선택(기본 1) | 지정한 횟수만큼 성공해야 끝, 여러 Pod를 동시에 띄울 수 있음 |
| work queue | `completions` 미지정, `parallelism`으로 동시 실행 수만 제어 | Pod들이 스스로 작업 큐를 비울 때까지 실행 |

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-example
spec:
  completions: 5
  parallelism: 2
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo index $JOB_COMPLETION_INDEX"]
```

Job이 만드는 Pod에는 `batch.kubernetes.io/job-name`, `batch.kubernetes.io/controller-uid` label이 붙는다(하위 호환을 위해 접두어 없는 `job-name`, `controller-uid` label도 함께 붙는다). Job controller가 각 Pod에 `batch.kubernetes.io/job-tracking` finalizer(v1.26 stable)를 걸어 완료 집계 중 Pod가 유실되지 않게 한다. `spec.selector`는 보통 자동 생성되며, `manualSelector: true`를 명시한 경우에만 직접 지정할 수 있다.



# 15. 실패 처리와 종료 제어
---

**backoffLimit** — 기본값 **6**. Pod가 실패할 때마다 지수 백오프(10초, 20초, 40초 … 최대 6분)로 재시도하다 이 횟수를 넘으면 Job이 `Failed`로 끝난다. `backoffLimitPerIndex`(Indexed Job 전용, v1.33 stable)를 지정하면 index마다 별도로 재시도 횟수를 세고, 이때 `backoffLimit`의 기본값은 사실상 무제한(2147483647)으로 바뀐다. `maxFailedIndexes`로 실패해도 되는 index의 총량을 제한할 수 있다.

**podFailurePolicy**(v1.31 stable) — 특정 exit code나 Pod condition(예: `DisruptionTarget`)에 따라 `FailJob`(즉시 실패 처리)·`Ignore`(재시도 횟수에 안 셈)·`Count`(기본 처리, backoffLimit에 카운트)·`FailIndex`(해당 index만 실패, Indexed 전용) 중 하나로 분기한다. 노드 축출처럼 애플리케이션 잘못이 아닌 실패를 재시도 낭비 없이 구분하는 데 쓴다. 사용하려면 `restartPolicy: Never`가 필수다.

```yaml
spec:
  backoffLimit: 6
  podFailurePolicy:
    rules:
      - action: Ignore
        onPodConditions:
          - type: DisruptionTarget   # 노드 축출 등으로 인한 실패는 재시도 횟수에서 제외
      - action: FailJob
        onExitCodes:
          containerName: worker
          operator: In
          values: [42]               # 이 exit code는 재시도 없이 즉시 실패 처리
```

**activeDeadlineSeconds** — `backoffLimit`보다 우선한다. 도달하면 재시도 여부와 무관하게 실행 중인 모든 Pod를 종료하고 Job을 `Failed`(reason `DeadlineExceeded`)로 표시한다.

**ttlSecondsAfterFinished**(v1.23 stable) — Job이 끝난(Complete 또는 Failed) 뒤 이 시간이 지나면 Job과 그 Pod들을 cascading 삭제한다. CronJob 등이 관리하지 않는 독립 Job(unmanaged Job)의 기본 삭제 정책은 `orphanDependents`라, 이 필드를 설정하지 않으면 끝난 뒤에도 Pod가 남아 쌓일 수 있다.

**suspend**(v1.24 stable) — `true`로 두면 실행 중인 Pod를 SIGTERM으로 종료하고 completions 집계에 반영하지 않은 채 대기한다. 다시 `false`로 바꿔 재개하면 `.status.startTime`이 리셋된다 — `activeDeadlineSeconds`의 기준 시각도 이때 함께 재설정된다.



# 16. CronJob이란: schedule과 concurrencyPolicy
---

**CronJob**(v1.21 stable)은 정해진 시각마다 Job을 만든다. `spec.schedule`은 표준 5-field cron 문법과 Vixie cron의 step 값(`a-b/n`, `*/n`)을 지원하고, 매크로로 `@yearly`(`@annually`), `@monthly`, `@weekly`, `@daily`(`@midnight`), `@hourly`를 공식 지원한다. `@every <duration>` 형태의 매크로는 CronJob 공식 문서에 명시돼 있지 않으므로, 지원한다고 단정할 수 없다 — 필요하면 표준 cron 필드로 원하는 주기를 구성해야 한다.

`spec.concurrencyPolicy`는 이전 스케줄로 만든 Job이 아직 끝나지 않았을 때의 동작을 정한다.

| 값 | 동작 |
|:--|:--|
| **Allow**(기본) | 이전 Job과 무관하게 새 Job을 또 만든다(동시 실행 허용). |
| **Forbid** | 이전 Job이 실행 중이면 이번 스케줄을 건너뛴다. |
| **Replace** | 이전 Job을 취소하고 새 Job으로 교체한다. |

이 정책은 **같은 CronJob이 만든 Job끼리만** 적용된다. 서로 다른 CronJob은 항상 독립적으로 동시 실행될 수 있다.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nightly-backup
spec:
  schedule: "0 2 * * *"        # 매일 02:00
  concurrencyPolicy: Forbid    # 이전 백업이 안 끝났으면 이번 스케줄은 건너뜀
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: busybox:1.36
              command: ["sh", "-c", "echo backup running"]
```



# 17. 놓친 스케줄과 이력 관리
---

`spec.startingDeadlineSeconds`를 지정하지 않으면 놓친 스케줄에 시간 제한이 없다. 10초 미만으로 지정하면 CronJob controller의 점검 주기(약 10초)보다 짧아 스케줄이 아예 실행되지 못할 수 있다. controller는 마지막 스케줄 시각 이후 놓친 횟수가 **100회를 넘으면** 그 이후를 건너뛰고 `too many missed start times...` 경고 이벤트를 남긴다 — 이 100이라는 값은 설정으로 바꿀 수 없는, 소스 코드에 박힌 상수다.

`successfulJobsHistoryLimit`(기본 **3**)과 `failedJobsHistoryLimit`(기본 **1**)은 각각 성공/실패한 과거 Job을 몇 개까지 보관할지 정한다. 0으로 설정하면 해당 유형을 아예 보관하지 않는다.

`spec.timeZone`(v1.27 stable)을 지정하지 않으면 kube-controller-manager 프로세스의 로컬 timezone 기준으로 schedule을 해석한다. `schedule` 문자열 안에 `CRON_TZ=`나 `TZ=` 접두사를 넣는 방식은 공식적으로 지원된 적이 없고, 넣으면 validation 오류가 난다 — timezone은 반드시 `spec.timeZone` 필드로 지정해야 한다.

생성되는 Job의 이름은 `<cronjob 이름>-<스케줄 시각의 Unix epoch초/60>` 형태다. 접미사 길이는 이 숫자의 자릿수만큼 늘어나는데, 공식 문서는 시간이 지나 자릿수가 늘어나는 상황까지 감안해 **최대 11자**(하이픈 1자 + 숫자 10자리)를 기준으로 CronJob 이름을 52자 이하로 두라고 권장한다. 2026년 현재는 이 숫자가 8자리라 실제 접미사는 9자에 그친다(Heading.21 실습의 `hello-29733154` 참고). Job 이름 63자 제한 때문에 나온 권장값이다. v1.32부터는 생성된 Job에 `batch.kubernetes.io/cronjob-scheduled-timestamp`(RFC3339) annotation이 추가돼 실제 스케줄된 시각을 그대로 확인할 수 있다.



# 18. 리소스 선택 기준
---

| 리소스 | 언제 쓰나 |
|:--|:--|
| Deployment | 무상태 앱, 어떤 복제본이 처리해도 상관없는 경우 |
| **StatefulSet** | 각 인스턴스가 고유한 identity·storage를 가져야 하는 상태 저장 앱 |
| **DaemonSet** | 노드마다 정확히 하나씩 떠 있어야 하는 인프라 성격의 Pod |
| **Job** | 한 번(또는 지정 횟수) 실행 후 끝나는 배치 작업 |
| **CronJob** | 그 배치 작업을 시각 기준으로 반복 실행 |



# 19. 실습: StatefulSet
---

3노드 minikube 클러스터가 실행 중이어야 한다(`kubectl get nodes`, `kubectl version`). 이 문서의 실습은 minikube v1.38.1(Kubernetes server v1.35.1) 클러스터에서 실제로 실행해 확인했다 — minikube 도구 자체의 버전과 그 위에 올라간 Kubernetes server 버전은 서로 다른 별개의 값이다.

Heading.2의 headless Service에, PVC를 실제로 마운트하는 `volumeMounts`와 `volumeClaimTemplates`를 더한 전체 매니페스트다. `statefulset.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
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
          volumeMounts:
            - name: www
              mountPath: /usr/share/nginx/html   # PVC를 실제로 마운트
  volumeClaimTemplates:
    - metadata:
        name: www
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

```bash
kubectl apply -f statefulset.yaml
kubectl rollout status statefulset/web             # web-0 → web-1 → web-2 순서로 Ready 대기
kubectl get pvc                                     # www-web-0, www-web-1, www-web-2

# 데이터가 PVC에 남는지 확인
kubectl exec web-0 -- sh -c 'echo hello > /usr/share/nginx/html/index.html'
kubectl delete pod web-0                            # 강제 삭제 → 같은 이름으로 재생성
kubectl wait --for=condition=Ready pod/web-0
kubectl exec web-0 -- cat /usr/share/nginx/html/index.html   # hello가 남아 있으면 같은 PVC에 재결합된 것

# scale-down: 역순 종료 관찰
kubectl scale statefulset web --replicas=1
kubectl get pods -l app=web -w                      # web-2가 먼저 Completed/사라지고 web-1이 뒤따름(Ctrl+C)

kubectl delete -f statefulset.yaml
kubectl get pvc                                     # 기본값(Retain)이라 PVC는 그대로 남는다
kubectl delete pvc -l app=web                       # 남은 PVC 정리
```

3노드 minikube 클러스터에서 실제로 실행해 확인한 결과다. `echo hello`로 쓴 내용은 Pod 삭제·재생성 후에도 `www-web-0` PVC에 그대로 남았고, PVC는 StatefulSet 삭제 후에도 기본 정책(`Retain`)대로 남아 있었다.



# 20. 실습: DaemonSet
---

`daemonset.yaml`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
spec:
  selector:
    matchLabels:
      app: node-agent
  template:
    metadata:
      labels:
        app: node-agent
    spec:
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f daemonset.yaml
kubectl get pods -l app=node-agent -o wide   # 노드 수만큼 Pod 생성 확인
kubectl get nodes -o jsonpath='{.items[*].metadata.name}'

# cordon한 노드에도 기존 Pod가 남는지 확인
kubectl cordon <노드이름>
kubectl get pods -l app=node-agent -o wide   # cordon 전과 동일하게 유지되면 unschedulable toleration이 적용된 것
kubectl uncordon <노드이름>

kubectl delete -f daemonset.yaml
```

3노드 minikube 클러스터에서 확인한 결과, `kubectl cordon`으로 `unschedulable:NoSchedule` taint가 붙은 뒤에도 그 노드의 DaemonSet Pod는 `Running` 상태를 그대로 유지했다.



# 21. 실습: Job과 CronJob
---

```bash
# Job: 병렬 완료 관찰
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-example
spec:
  completions: 5
  parallelism: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sh", "-c", "echo done"]
EOF

kubectl get pods -l job-name=batch-example -w   # 동시에 최대 2개까지만 실행(Ctrl+C)
kubectl get job batch-example                    # COMPLETIONS 5/5 확인
kubectl delete job batch-example

# CronJob: 스케줄 실행 관찰(1분마다 실행되도록 짧게 설정)
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "* * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: hello
              image: busybox:1.36
              command: ["sh", "-c", "date; echo hello"]
EOF

kubectl get jobs -w                             # 1분 간격으로 새 Job이 생기는지 관찰(수 분 대기 후 Ctrl+C)
kubectl get jobs -o custom-columns=NAME:.metadata.name,"SCHEDULED:.metadata.annotations.batch\.kubernetes\.io/cronjob-scheduled-timestamp"
kubectl delete cronjob hello
```

3노드 minikube 클러스터에서 확인한 결과다. Job은 `<cronjob 이름>-<epoch초/60>` 형태(예: `hello-29733154`)로 1분마다 하나씩 생겼고, `cronjob-scheduled-timestamp` annotation에는 실제 스케줄된 시각이 RFC3339로 남았다.



# 22. 디버깅
---

| 증상 | 원인 | 확인 명령 |
|:--|:--|:--|
| StatefulSet rollout이 특정 ordinal에서 멈춤 | `OrderedReady`에서 새 template Pod가 영구히 Ready 안 됨(Heading.6) | `kubectl describe statefulset`, `kubectl get pods -o wide` — 문제 Pod를 수동 삭제해 복구 |
| StatefulSet scale-down이 멈춤 | 더 높은 ordinal Pod가 아직 완전히 종료되지 않음 | `kubectl get pods -w` |
| PVC가 예상과 다르게 남거나 사라짐 | `persistentVolumeClaimRetentionPolicy` 미설정(기본 Retain) 오해 | `kubectl get pvc -o yaml`의 `ownerReferences` |
| DaemonSet rollout이 특정 노드에서만 멈춤 | 그 노드의 리소스 부족으로 새 Pod 스케줄 불가 | `kubectl get pods -o wide` vs `kubectl get nodes`, `kubectl describe node` |
| DaemonSet rollout이 전체적으로 멈춤 | 새 template 자체가 깨짐(`ImagePullBackOff`·`CrashLoopBackOff`) | `kubectl rollout status ds/<이름>`, `kubectl get pods -l <selector>` |
| DaemonSet Pod가 control-plane 노드에 없음 | control-plane taint는 자동 tolerate 목록에 없음(Heading.11) | `kubectl get node <cp노드> -o jsonpath='{.spec.taints}'`와 pod template의 `tolerations` 비교 |
| Job이 `Failed`로 끝남 | `backoffLimit`(기본 6) 초과 | `kubectl describe job` Events의 `BackoffLimitExceeded` |
| Job이 시간 초과로 실패 | `activeDeadlineSeconds` 도달 | `kubectl get job -o yaml`의 `status.conditions`(reason `DeadlineExceeded`) |
| CronJob이 예정 시각에 Job을 안 만듦 | 놓친 스케줄이 100개 초과, 또는 `startingDeadlineSeconds` 초과 | `kubectl get events` — `too many missed start times...` 경고 |
| CronJob이 예상보다 덜 실행됨 | `concurrencyPolicy: Forbid`인데 이전 Job이 아직 실행 중 | `kubectl get jobs --sort-by=.metadata.creationTimestamp` |



# 23. 참고 링크
---

─ StatefulSet — <https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/>  
─ DaemonSet — <https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/>  
─ DaemonSet 업데이트 — <https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/>  
─ Job — <https://kubernetes.io/docs/concepts/workloads/controllers/job/>  
─ CronJob — <https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/>  
─ StatefulSet known issue(rollout이 멈추는 경우) — <https://github.com/kubernetes/kubernetes/issues/67250>  
─ Kubernetes v1.36 릴리스 노트 — <https://kubernetes.io/blog/2026/04/22/kubernetes-v1-36-release/>
