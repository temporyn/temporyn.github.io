# Namespace ResourceQuota LimitRange

> 선행: [Pod](/kubernetes/Pod/), minikube 클러스터.

클러스터를 논리적으로 나누는 **Namespace**와, 그 네임스페이스 단위로 자원 사용을 제한하는 **ResourceQuota·LimitRange**. 셋은 "네임스페이스로 구획을 나누고, 그 안의 자원 사용을 제한한다"는 한 흐름이다.

---

## Namespace

### 개념

**네임스페이스**는 한 클러스터를 논리적으로 나누는 가상 구획이다. 팀·환경(dev/prod)별로 리소스를 분리한다.

- 리소스 이름은 **같은 네임스페이스 안에서만 유일**하면 된다. 네임스페이스가 다르면 같은 이름을 써도 된다.
- 물리적 격리가 아니라 이름·정책의 논리적 분리다.
- 사용자가 수십 명 이하로 적으면 굳이 나눌 필요 없다.

### 기본 네임스페이스 4개

| 네임스페이스 | 용도 |
|:-------------|:-----|
| **default** | 사용자 리소스 기본 위치. 네임스페이스를 안 지정하면 여기. |
| **kube-system** | 쿠버네티스 시스템이 만든 객체. |
| **kube-public** | 모든 클라이언트가 읽을 수 있음. 클러스터 공용. |
| **kube-node-lease** | 노드 하트비트(Lease) 보관. 노드 장애 감지용. |

### 네임스페이스에 속하는 것 / 아닌 것

- **속함(namespaced)**: Pod, Service, Deployment, ConfigMap, Secret, PVC 등 대부분.
- **클러스터 전역(not namespaced)**: Node, PersistentVolume, StorageClass, 그리고 Namespace 자신.

```bash
kubectl api-resources --namespaced=true    # 네임스페이스 리소스
kubectl api-resources --namespaced=false   # 클러스터 전역 리소스
```

### 다루기

```bash
kubectl get namespaces                       # 목록 (ns 축약 가능)
kubectl create namespace demo                # 생성

kubectl get pods -n demo                     # 특정 네임스페이스 대상
kubectl run web --image=nginx:1.27 -n demo

# 현재 컨텍스트의 기본 네임스페이스 고정
kubectl config set-context --current --namespace=demo
```

Service DNS도 네임스페이스를 포함한다: 같은 네임스페이스면 `<service>`, 다른 네임스페이스면 `<service>.<namespace>.svc.cluster.local`.

---

## requests / limits (선행 개념)

아래 두 정책은 컨테이너의 **자원 요청·상한**을 기준으로 동작하므로 먼저 짚는다.

```yaml
resources:
  requests:                 # 스케줄링 시 확보할 최소량
    cpu: 250m               # 0.25 코어 (1000m = 1코어)
    memory: 256Mi
  limits:                   # 넘으면 안 되는 상한
    cpu: 500m
    memory: 512Mi
```

- **requests**: 스케줄러가 이만큼 여유 있는 노드에 배치한다.
- **limits**: 이 값을 초과하면 CPU는 조절(throttle), 메모리는 컨테이너가 종료(OOMKilled)된다.

---

## ResourceQuota

네임스페이스 **전체 합계**를 제한한다. admission(생성) 시점에 초과하면 **403으로 거부**한다.

| 종류 | 예시 필드 |
|:-----|:----------|
| **compute** | `requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory` |
| **object count** | `pods`, `services`, `configmaps`, `persistentvolumeclaims`, `count/deployments.apps` |
| **storage** | `requests.storage`, `persistentvolumeclaims` |

> 주의: 어떤 네임스페이스에 `cpu`/`memory` 쿼터가 걸리면, 그 네임스페이스의 **모든 Pod는 해당 자원의 requests/limits를 명시해야** 한다(안 하면 거부). 이 누락 문제는 아래 LimitRange의 기본값 주입으로 막는다.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
  namespace: demo
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "5"
```

```bash
kubectl get resourcequota -n demo
kubectl describe resourcequota demo-quota -n demo   # Used / Hard 사용량 확인
```

---

## LimitRange

**개별 객체(Container·Pod·PVC)** 단위로 제약하고 **기본값을 주입**한다. 역시 네임스페이스 범위다.

- ResourceQuota가 "합계 총량"이라면, LimitRange는 "객체 하나하나의 하한·상한·기본값"이다.
- 필드: `default`(기본 limit), `defaultRequest`(기본 request), `min`, `max`, `maxLimitRequestRatio`. `type`은 `Container`/`Pod`/`PersistentVolumeClaim`.
- 동작: requests/limits를 안 적은 컨테이너에 **기본값을 주입**하고, `min`/`max` 위반 시 거부한다.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: demo-limits
  namespace: demo
spec:
  limits:
    - type: Container
      default:              # limit 미지정 시 적용
        cpu: 500m
        memory: 512Mi
      defaultRequest:       # request 미지정 시 적용
        cpu: 250m
        memory: 256Mi
      min:
        cpu: 100m
        memory: 128Mi
      max:
        cpu: "1"
        memory: 1Gi
```

ResourceQuota와 함께 쓰면 궁합이 좋다: 쿼터가 requests/limits 명시를 강제하는데, LimitRange가 기본값을 넣어 줘 **누락으로 인한 거부를 방지**한다.

---

## 실습: 네임스페이스에 쿼터·리밋 걸기

```bash
kubectl create namespace demo
kubectl apply -f demo-limits.yaml     # 위 LimitRange
kubectl apply -f demo-quota.yaml      # 위 ResourceQuota
```

requests/limits를 안 적어도 LimitRange 기본값이 주입되는지 확인한다.

```bash
kubectl run web --image=nginx:1.27 -n demo

# 주입된 resources 확인 (requests 250m/256Mi, limits 500m/512Mi)
kubectl get pod web -n demo -o jsonpath='{.spec.containers[0].resources}'; echo

# 쿼터 사용량 확인
kubectl describe resourcequota demo-quota -n demo
```

정리는 네임스페이스만 지우면 안의 모든 것이 함께 삭제된다.

```bash
kubectl delete namespace demo
```

---

## 참고 링크

- Namespaces: <https://kubernetes.io/ko/docs/concepts/overview/working-with-objects/namespaces/>
- ResourceQuota: <https://kubernetes.io/ko/docs/concepts/policy/resource-quotas/>
- LimitRange: <https://kubernetes.io/ko/docs/concepts/policy/limit-range/>
