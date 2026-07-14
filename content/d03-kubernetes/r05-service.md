
---

***index***

[1. Service란](#1-service란)  
[2. selector에서 EndpointSlice까지](#2-selector에서-endpointslice까지)  
[3. ClusterIP 할당](#3-clusterip-할당)  
[4. headless Service](#4-headless-service)  
[5. selector 없는 Service](#5-selector-없는-service)  
[6. Service 타입의 계층 구조](#6-service-타입의-계층-구조)  
[7. NodePort와 LoadBalancer](#7-nodeport와-loadbalancer)  
[8. ExternalName](#8-externalname)  
[9. ports 필드: port·targetPort·nodePort](#9-ports-필드-porttargetportnodeport)  
[10. readiness와 EndpointSlice 상태](#10-readiness와-endpointslice-상태)  
[11. externalTrafficPolicy와 internalTrafficPolicy](#11-externaltrafficpolicy와-internaltrafficpolicy)  
[12. sessionAffinity](#12-sessionaffinity)  
[13. trafficDistribution](#13-trafficdistribution)  
[14. DNS: FQDN과 SRV record](#14-dns-fqdn과-srv-record)  
[15. dual-stack](#15-dual-stack)  
[16. 주요 필드 정리](#16-주요-필드-정리)  
[17. 실습: ClusterIP·NodePort·headless](#17-실습-clusternodeportheadless)  
[18. 디버깅](#18-디버깅)  
[19. 참고 링크](#19-참고-링크)

---



# 1. Service란
---

Pod IP는 Pod가 재생성될 때마다 바뀐다([Pod](/kubernetes/pod/) 참고). **Service**는 label selector로 묶은 Pod 그룹에 안정적인 가상 IP와 DNS 이름을 부여해, 이 휘발성을 감춘다. Service의 controller가 selector에 매칭되는 Pod를 계속 스캔하며 그 결과를 **EndpointSlice**에 반영하고, kube-proxy(또는 CNI)가 그 EndpointSlice를 실제 네트워크 규칙(iptables·ipvs·nftables 등)으로 바꾼다 — 이 규칙 자체의 구현 방식은 클러스터 구조 문서([Prepared](/kubernetes/prepared/) 참고)에서 다뤘다.

selector가 Pod의 `metadata.labels`와 일치하는지가 연결의 시작점이다. selector 자체는 Deployment·StatefulSet과 마찬가지로 `matchLabels` 형태로 적는다.



# 2. selector에서 EndpointSlice까지
---

Service의 `spec.selector`에 매칭되는 Pod의 IP·포트 목록이 **EndpointSlice**(`kubernetes.io/service-name` label로 소속 Service를 식별)에 기록된다. EndpointSlice API는 v1.21에 stable이 됐고, `Serving`·`Terminating` condition은 v1.26에 stable이 됐다.

EndpointSlice 하나에는 기본 최대 **100개**의 endpoint가 들어가고, kube-controller-manager의 `--max-endpoints-per-slice` 플래그로 최대 1000까지 늘릴 수 있다. 대상 Pod가 많으면 여러 EndpointSlice로 나뉘어 저장된다.

이전에는 **Endpoints**(단수형 API, Service 하나당 object 하나)가 이 역할을 했다. Endpoints는 모든 주소를 단일 object에 담기 때문에 백엔드가 1000개를 넘으면 나머지를 truncate하고 `endpoints.kubernetes.io/over-capacity: truncated` annotation을 붙인다. 이 확장성 한계가 EndpointSlice가 나온 배경이다. Endpoints API는 **v1.33부터 공식 deprecated**됐다(제거 계획은 없고, conformance 요구사항에서 controller 구동 의무만 빠지는 방향).

```bash
kubectl get endpointslices -l kubernetes.io/service-name=<svc이름>
```



# 3. ClusterIP 할당
---

일반 Service(headless가 아닌 경우)는 생성 시 클러스터 내부에서만 유효한 가상 IP인 **ClusterIP**를 받는다. 예전에는 이 IP를 kube-apiserver가 메모리에 유지하는 내부 할당 맵(in-memory allocation map)에서 뽑았다. `MultiCIDRServiceAllocator`(v1.27 alpha → v1.31 beta → **v1.33 stable**)는 이 할당을 `IPAddress`·`ServiceCIDR` API object 기반으로 옮겨, IPv6 상한을 기존 `/108`에서 `/64`까지 확장했다. 예전 방식과 병행 기록하던 `DisableAllocatorDualWrite`는 v1.34에 stable, v1.35에 GA로 고정돼 v1.36 기준으로는 새 allocator만 동작한다고 볼 수 있다.

ClusterIP 대역은 상위(동적 자동 할당용)·하위(사용자 수동 지정용) 밴드로 나뉜다(`min(max(16, CIDR크기/16), 256)`, v1.26 stable). `spec.clusterIP`를 직접 지정하려면 충돌 위험이 낮은 하위 밴드에서 고르는 편이 안전하다. Service를 지우고 같은 이름으로 다시 만들 때 이전과 같은 ClusterIP가 재할당되는지는 공식 문서에 명시돼 있지 않다 — 할당 메커니즘상 매번 새로 뽑는다고 보는 편이 안전하며, 고정 IP가 필요하면 `spec.clusterIP`를 명시해야 한다.



# 4. headless Service
---

`spec.clusterIP: None`으로 만들면 가상 IP를 할당하지 않는 **headless Service**가 된다. kube-proxy가 관여하지 않고 로드밸런싱도 하지 않는다.

selector가 있으면 EndpointSlice는 그대로 생성되고, DNS 조회 시 Service 하나의 IP 대신 **각 Pod의 IP를 A/AAAA record로 직접** 반환한다. StatefulSet이 Pod별 고유 DNS 이름을 얻는 데 이 방식을 쓴다(자세한 내용은 [StatefulSet](/kubernetes/statefulset-daemonset-job-cronjob/) 참고).

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
```



# 5. selector 없는 Service
---

selector를 아예 생략하면 control plane이 EndpointSlice를 자동으로 만들지 않는다. 클러스터 밖 DB, 다른 namespace·클러스터의 서비스, 마이그레이션 중인 워크로드처럼 Pod가 아닌 대상을 가리키고 싶을 때 쓰는 방식으로, 사용자가 `kubernetes.io/service-name` label을 가진 EndpointSlice를 직접 만들어 채운다.

selector 없는 headless Service(`clusterIP: None`이면서 selector도 없는 경우)는 DNS 응답이 또 달라진다. `ExternalName` 타입이면 CNAME을, 그 외 타입이면 수동으로 등록한 ready endpoint의 A/AAAA record를 반환한다 — 이때는 `port`와 `targetPort`가 반드시 같아야 한다.



# 6. Service 타입의 계층 구조
---

Service 타입 4가지(`ClusterIP`가 사실상 기본, `NodePort`, `LoadBalancer`, `ExternalName`)는 서로 독립적인 병렬 옵션이 아니라 **계층적으로 겹쳐 쌓인다**. `NodePort`는 `ClusterIP` 위에, `LoadBalancer`는 `NodePort` 위에 쌓이는 방식으로 정의돼 있다.

| 타입 | 관계 |
|:--|:--|
| **ClusterIP** | 기반. 클러스터 내부 전용 가상 IP. |
| **NodePort** | ClusterIP에 더해, 모든 노드에서 같은 포트를 열어 외부에서 `<노드IP>:<nodePort>`로 접근 가능하게 한다. |
| **LoadBalancer** | NodePort에 더해, cloud-controller-manager(또는 MetalLB 같은 대안)가 외부 로드밸런서를 그 nodePort로 연결한다. |
| **ExternalName** | 이 계층에 속하지 않는 별도 방식. DNS CNAME만 반환한다(Heading.8). |

이 중첩 구조에는 예외가 하나 있다. `spec.allocateLoadBalancerNodePorts: false`(기본 `true`)로 지정하면 `LoadBalancer` 타입이면서도 NodePort 할당 자체를 건너뛸 수 있다(Heading.7).



# 7. NodePort와 LoadBalancer
---

**NodePort** — `spec.type: NodePort`로 지정하면 모든 노드가 같은 포트(기본 범위 **30000-32767**, `--service-node-port-range`로 조정)를 열어 그 노드로 들어온 트래픽을 Service로 넘긴다. 이 범위도 ClusterIP처럼 상위(동적 자동 할당 우선)·하위(수동 지정용) 밴드로 나뉜다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080   # 생략하면 자동 할당
```

**LoadBalancer** — `spec.type: LoadBalancer`는 NodePort에 준하는 설정을 적용한 뒤, cloud-controller-manager가 외부 로드밸런서를 프로비저닝해 그 nodePort로 트래픽을 넘기도록 구성한다. 생성은 비동기라 `.status.loadBalancer.ingress`에 실제 주소가 채워지기까지 시간이 걸린다. `spec.allocateLoadBalancerNodePorts: false`(기본 `true`)로 NodePort 할당 자체를 생략할 수 있다.

클라우드 기본 구현이 아닌 다른 LB 구현(예: on-prem의 MetalLB)을 쓰려면 `spec.loadBalancerClass`(v1.24 stable)를 지정한다. MetalLB는 지정된 IP pool에서 주소를 골라 `.status.loadBalancer.ingress`에 채우고, Layer2 모드(ARP/NDP로 한 노드가 그 IP의 소유권을 주장)나 BGP 모드(모든 노드가 라우터와 피어링)로 네트워크에 알린다. minikube는 `--cloud-provider`가 없으므로 `minikube tunnel`이 이 역할의 로컬 대용을 한다.



# 8. ExternalName
---

`spec.type: ExternalName`은 selector 없이 `spec.externalName`에 적은 DNS 이름으로 **CNAME**을 반환한다. Pod를 갖지 않으므로 kube-proxy는 이 타입에 아무 규칙도 만들지 않는다 — virtual IP 메커니즘 자체가 ExternalName을 제외한 나머지 타입에만 구현돼 있다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

CNAME이라 클라이언트가 원래 요청한 HTTP Host header나 TLS SNI가 실제 목적지(`db.example.com`)와 달라질 수 있다는 점에 주의해야 한다.



# 9. ports 필드: port·targetPort·nodePort
---

| 필드 | 필수 | 뜻 |
|:--|:--:|:--|
| `port` | 예 | 클라이언트가 이 Service에 접속하는 포트 |
| `targetPort` | 아니오 | 실제 Pod 컨테이너 포트. 미지정 시 `port`와 동일. 문자열이면 컨테이너의 named port 이름으로 조회 |
| `nodePort` | 아니오 | NodePort·LoadBalancer 타입에서만 사용. 미지정 시 자동 할당 |
| `protocol` | 아니오 | 기본 `TCP`. `TCP`·`UDP`·`SCTP` 중 하나 |

`clusterIP: None`(headless)인 경우 `targetPort`는 무시되므로 `port`와 같은 값을 써야 한다. 컨테이너마다 다른 실제 포트 번호를 가리키는 named `targetPort`를 쓰면, 그 차이 때문에 대상 Pod들이 서로 다른 EndpointSlice로 나뉘어 관리될 수 있다.



# 10. readiness와 EndpointSlice 상태
---

EndpointSlice의 `serving` condition은 Pod의 `Ready` condition에 매핑된다 — readiness probe가 실패하면 `serving: false`가 되어 그 Pod는 정상 트래픽 대상에서 빠진다([Pod의 probe](/kubernetes/pod/) 참고). `terminating`은 Pod가 삭제 표시(deletion timestamp)를 받는 순간 켜진다. 최종적으로 `ready = serving && !terminating`이다.

kube-proxy 같은 service proxy는 평소 `terminating` endpoint를 무시하지만, **그 Service의 모든 endpoint가 terminating 상태**가 되면 예외적으로 `serving && terminating`인 endpoint에도 트래픽을 라우팅한다. rolling update로 모든 Pod가 한꺼번에 종료 단계에 들어가는 순간에도 연결을 완전히 끊지 않기 위한 fallback이다.

`publishNotReadyAddresses: true`로 지정하면 이 판정과 무관하게 항상 `ready: true`로 취급된다. 공식 용례는 StatefulSet의 headless Service가 아직 준비되지 않은 Pod의 주소까지 SRV DNS record로 전파해, 클러스터를 구성 중인 Pod끼리 서로 발견(peer discovery)할 수 있게 하는 것이다.



# 11. externalTrafficPolicy와 internalTrafficPolicy
---

트래픽을 어느 노드의 endpoint로 보낼지 정하는 정책이다. `externalTrafficPolicy`는 클러스터 밖에서 들어온 트래픽(NodePort·LoadBalancer)에, `internalTrafficPolicy`(v1.26 stable)는 클러스터 안에서 온 트래픽에 각각 적용된다.

| 값 | 동작 |
|:--|:--|
| **Cluster**(기본) | 노드 위치와 무관하게 모든 endpoint에 고르게 분산한다. |
| **Local** | 트래픽을 받은 그 노드의 로컬 endpoint에만 보낸다. 그 노드에 로컬 endpoint가 없으면 트래픽을 **버린다**(다른 노드로 넘기지 않음). |

`Local`은 source IP를 그대로 보존한다는 장점이 있지만, 그 대가로 노드별 endpoint 개수가 다르면 부하가 고르게 분산되지 않고, endpoint가 없는 노드로 트래픽이 도달하면 그냥 실패한다.

`externalTrafficPolicy: Cluster`에서 로드밸런서 health check는 kube-proxy의 `${NODE_IP}:10256/healthz`를 쓴다(iptables 모드 기준 timeout은 `2 × iptables.syncPeriod`). `Local`이면 `healthCheckNodePort`를 통해 그 노드에 로컬 endpoint가 있는지로 200/503을 반환한다 — 노드가 삭제되는 과정에서는 readiness가 먼저 503으로 실패해 연결이 새로 붙지 않도록 드레이닝을 지원한다.



# 12. sessionAffinity
---

`spec.sessionAffinity`는 `None`(기본) 또는 `ClientIP` 중 하나다. `ClientIP`로 설정하면 같은 클라이언트 IP의 요청을 계속 같은 Pod로 보낸다. 유지 시간은 `sessionAffinityConfig.clientIP.timeoutSeconds`로 조절하며 기본값은 **10800초(3시간)**, 유효 범위는 1~86400초다.

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600   # 1시간으로 단축
```



# 13. trafficDistribution
---

`spec.trafficDistribution`(KEP-4444, v1.30 alpha → v1.31 beta → **v1.33 stable**)은 zone·node 근접성을 우선하는 라우팅 힌트다.

| 값 | 동작 |
|:--|:--|
| `PreferSameZone`(구 `PreferClose`) | 같은 zone의 endpoint를 우선하고, 없으면 클러스터 전체로 fallback한다. |
| `PreferSameNode` | 같은 노드의 endpoint를 우선하고, 없으면 같은 zone → 클러스터 전체 순으로 fallback한다(`PreferSameTrafficDistribution` gate, v1.33 alpha → v1.34 beta → **v1.35 stable**). |
| 미설정 | 모든 endpoint에 균등 분산한다. |

`externalTrafficPolicy`나 `internalTrafficPolicy`가 `Local`이면 그 트래픽 종류에 한해 이 필드보다 우선한다. 둘 다 `Cluster`(기본)면 `trafficDistribution`이 라우팅을 가이드한다.



# 14. DNS: FQDN과 SRV record
---

Service는 `<service 이름>.<namespace>.svc.<cluster domain>` 형태의 A/AAAA record로 조회된다. cluster domain은 kubelet의 `--cluster-domain`으로 설정하며 기본값(및 minikube의 기본값)은 `cluster.local`이다. Pod의 `resolv.conf`에는 `<자신의 namespace>.svc.cluster.local`, `svc.cluster.local`, `cluster.local` 순으로 search domain이 설정돼 있어, 같은 namespace의 Service는 이름만으로도 조회된다.

이름 있는 port가 있으면 `_<port 이름>._<protocol>.<service>.<namespace>.svc.cluster.local` 형태의 SRV record도 함께 생성된다. 일반 Service는 이 SRV 조회에 단일 응답(포트+Service FQDN)을 주지만, headless Service는 Pod마다 하나씩 여러 응답을 준다(Heading.4).

CoreDNS는 kubeadm 기본 DNS 애드온으로 v1.11부터 쓰였고 v1.13에 정식 GA됐다.



# 15. dual-stack
---

`spec.ipFamilyPolicy`로 IPv4/IPv6 동시 지원 여부를 정한다.

| 값 | 동작 |
|:--|:--|
| **SingleStack**(기본) | 한 IP family만 사용 |
| **PreferDualStack** | 클러스터가 dual-stack이면 두 family 모두 할당, 아니면 하나만 |
| **RequireDualStack** | 두 family 모두 필수, 지원 안 되면 실패 |

`spec.ipFamilies`와 `spec.clusterIPs`는 각각 최대 2개까지 값을 가질 수 있고, `ipFamilyPolicy`에 종속적으로 채워진다.



# 16. 주요 필드 정리
---

| 필드 | 기본 | 뜻 |
|:--|:--:|:--|
| `type` | ClusterIP | Service 타입 |
| `selector` | (선택) | 대상 Pod label. 없으면 EndpointSlice 수동 관리 |
| `clusterIP` | 자동 할당 | 가상 IP. `None`이면 headless |
| `sessionAffinity` | None | 세션 고정 여부 |
| `sessionAffinityConfig.clientIP.timeoutSeconds` | 10800 | ClientIP 고정 유지 시간(초) |
| `externalTrafficPolicy` | Cluster | 외부 트래픽 라우팅 정책 |
| `internalTrafficPolicy` | Cluster | 내부 트래픽 라우팅 정책 |
| `trafficDistribution` | (미설정=균등) | zone/node 근접 라우팅 힌트 |
| `allocateLoadBalancerNodePorts` | true | LoadBalancer에서 NodePort 자동 할당 여부 |
| `ipFamilyPolicy` | SingleStack | dual-stack 여부 |
| `publishNotReadyAddresses` | false | not-ready Pod도 DNS에 전파할지 |



# 17. 실습: ClusterIP·NodePort·headless
---

minikube 클러스터가 실행 중이어야 한다(`kubectl get nodes`).

```bash
kubectl run web --image=nginx:1.27 --labels=app=web --port=80
kubectl expose pod web --port=80 --target-port=80 --name=web-svc
kubectl get svc web-svc                              # TYPE ClusterIP, CLUSTER-IP 할당 확인
kubectl get endpointslices -l kubernetes.io/service-name=web-svc

# ClusterIP로 접속 확인 (클러스터 내부에서)
kubectl run -it --rm curl --image=busybox:1.36 --restart=Never -- wget -qO- web-svc.default.svc.cluster.local
```

```bash
# NodePort로 바꿔 모든 노드 IP에서 접속 확인
kubectl patch svc web-svc -p '{"spec":{"type":"NodePort"}}'
kubectl get svc web-svc                               # PORT(S) 열에서 nodePort 확인
sleep 5                                                 # 노드별 프록시 규칙이 반영될 시간을 둔다
NODE_PORT=$(kubectl get svc web-svc -o jsonpath='{.spec.ports[0].nodePort}')
for ip in $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'); do
  echo "-- $ip --"
  curl -sS --max-time 5 "http://$ip:$NODE_PORT" | head -1
done
```

```bash
# headless로 바꿔 DNS가 Pod IP를 직접 반환하는지 확인
kubectl delete svc web-svc
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - port: 80
EOF
kubectl run -it --rm dnscheck --image=busybox:1.36 --restart=Never -- nslookup web-headless.default.svc.cluster.local
kubectl get pod web -o jsonpath='{.status.podIP}'    # nslookup 결과와 같은 IP인지 비교

kubectl delete pod web
kubectl delete svc web-headless
```

3노드 minikube v1.38.1(Kubernetes server v1.35.1) 클러스터에서 실행해 확인한 결과다. ClusterIP Service는 클러스터 안에서 `wget`으로 정상 응답했다. NodePort로 바꾼 직후에는 프록시 규칙이 아직 반영되지 않아 `curl`이 연결 자체에 실패했고, 몇 초 뒤 재시도하니 세 노드 IP 모두에서 같은 응답을 받았다. headless Service의 `nslookup`은 Service의 가상 IP가 아니라 Pod 자신의 IP를 직접 반환했다.



# 18. 디버깅
---

공식 디버깅 절차는 다음 순서로 원인을 좁혀 나간다.

1. `kubectl get svc <이름>`으로 Service 자체가 존재하고 `CLUSTER-IP`가 할당됐는지 확인한다.
2. 대상 Pod에 영향을 주는 NetworkPolicy ingress 규칙이 있는지 검토한다(세부는 별도 문서 범위).
3. `nslookup <service>.<namespace>.svc.cluster.local`로 DNS가 정상 응답하는지 확인한다.
4. `kubectl get service <이름> -o json`으로 `ports[].port`/`targetPort`/`selector`가 의도한 값과 일치하는지 재확인한다.
5. `kubectl get endpointslices -l kubernetes.io/service-name=<이름>`으로 `ENDPOINTS`가 채워져 있는지 확인한다.

| 증상 | 대표 원인 | 확인 |
|:--|:--|:--|
| EndpointSlice의 `ENDPOINTS`가 `<none>` | selector와 Pod label의 오타·불일치(가장 흔한 원인) | `kubectl get pods -l <selector>`로 실제 매칭 여부 비교 |
| EndpointSlice는 있는데 연결 실패 | `targetPort` 오타 또는 named port 이름 불일치 | `kubectl get pod <pod> -o yaml`의 `containerPort`와 대조 |
| Pod는 Running인데 EndpointSlice에서 빠짐 | readiness probe 실패로 `serving: false`(Heading.10) | `kubectl get pod -o yaml`의 `status.conditions[Ready]` |
| Service·EndpointSlice·label 모두 정상인데 연결 실패 | NetworkPolicy가 ingress를 차단 | 관련 NetworkPolicy object 검토 |
| `externalTrafficPolicy: Local`에서 특정 노드로만 접근 실패 | 그 노드에 로컬 endpoint가 없어 kube-proxy가 트래픽을 버림 | `healthCheckNodePort`의 200/503 응답 확인 |



# 19. 참고 링크
---

─ Service — <https://kubernetes.io/docs/concepts/services-networking/service/>  
─ Service 접속 방법(Virtual IP·kube-proxy) — <https://kubernetes.io/docs/reference/networking/virtual-ips/>  
─ Service Internal Traffic Policy — <https://kubernetes.io/docs/concepts/services-networking/service-traffic-policy/>  
─ EndpointSlice — <https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/>  
─ DNS for Services and Pods — <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/>  
─ Service 디버깅 — <https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/>  
─ ClusterIP 할당(band 공식) — <https://kubernetes.io/docs/concepts/services-networking/cluster-ip-allocation/>  
─ Kubernetes v1.33: Endpoints에서 EndpointSlice로의 전환 — <https://kubernetes.io/blog/2025/04/24/endpoints-deprecation/>
