# Service

> 선행: [Pod](/kubernetes/Pod/)의 개념과 minikube 클러스터.

Pod 집합에 안정적인 네트워크 접근점을 제공하는 **Service**.

---

## Service란

Pod는 일회용이라 죽고 다시 뜨며 그때마다 **IP가 바뀐다**. 그래서 Pod IP를 직접 물고 통신하면 상대가 교체되는 순간 끊긴다. Service는 이 바뀌는 Pod들 앞에 두는 **고정 접근점**이다.

- 고정 가상 IP(ClusterIP)와 DNS 이름을 가진다.
- **셀렉터(selector)** 로 라벨이 맞는 Pod들을 골라 트래픽을 분산한다.
- 뒤의 Pod가 교체·증감돼도 접근점은 그대로다.

```text
   Service (stable VIP + DNS, selector: app=web)
        |          |          |
      [Pod]      [Pod]      [Pod]
     (IP 변동)   (IP 변동)   (IP 변동)
```

→ 클라이언트는 Service 하나만 바라보고, 뒤의 Pod 교체는 신경 쓰지 않는다.

---

## Pod 연결: selector와 EndpointSlice

Service에 selector를 지정하면, 쿠버네티스가 라벨이 맞는 Pod들의 IP를 모아 **EndpointSlice** 객체에 자동으로 채우고 Pod가 생기고 사라질 때마다 갱신한다. 각 노드의 **kube-proxy**가 이 정보를 iptables(또는 IPVS) 규칙으로 반영해, ClusterIP로 들어온 트래픽을 실제 Pod로 라우팅한다.

즉 흐름은 이렇다.

```text
클라이언트 → Service(ClusterIP) → kube-proxy 규칙 → EndpointSlice의 Pod 중 하나
```

---

## 포트 3종

Service 정의에서 헷갈리기 쉬운 세 포트다.

| 필드 | 의미 |
|:-----|:-----|
| **port** | Service 자신이 여는 포트(ClusterIP 쪽). |
| **targetPort** | 트래픽이 전달될 **Pod(컨테이너) 포트**. 생략 시 `port`와 같은 값. |
| **nodePort** | (NodePort 타입 한정) 각 노드가 외부로 여는 포트. 범위 **30000–32767**. |

---

## Service 타입

`spec.type`으로 지정하며 **기본값은 ClusterIP**다.

| 타입 | 접근 범위 |
|:-----|:----------|
| **ClusterIP** (기본) | 클러스터 **내부 전용** 가상 IP. 내부 마이크로서비스 간 통신용. |
| **NodePort** | 모든 노드의 `<NodeIP>:<nodePort>`로 **외부 노출**. ClusterIP도 함께 생성됨. |
| **LoadBalancer** | 클라우드 로드밸런서로 외부 노출(클라우드 환경 필요). NodePort·ClusterIP 포함. |
| **ExternalName** | 셀렉터 없이 외부 DNS 이름으로의 **CNAME 별칭**. 프록시·로드밸런싱 아님. |

로컬 minikube에서는 `LoadBalancer`를 걸어도 실제 클라우드 LB가 없어 외부 IP가 `<pending>`으로 남는다. 실습은 ClusterIP와 NodePort로 한다.

---

## DNS 이름

Service는 DNS 이름으로 접근하는 것이 표준이다(IP는 바뀔 수 있으므로).

- 같은 네임스페이스: `<service>`
- 전체 이름(FQDN): `<service>.<namespace>.svc.cluster.local`

예: `default` 네임스페이스의 `web` Service는 `web` 또는 `web.default.svc.cluster.local`로 부른다.

---

## Headless Service

`clusterIP: None`으로 두면 가상 IP·로드밸런싱 없이 DNS가 **개별 Pod IP들을 직접 반환**한다. Pod 각각을 지목해야 하는 StatefulSet(예: DB 클러스터) 등에서 쓴다.

---

## 매니페스트

가장 단순한 ClusterIP Service다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web            # 이 라벨을 가진 Pod로 트래픽 전달
  ports:
    - protocol: TCP
      port: 80          # Service 포트
      targetPort: 80    # Pod 포트
```

---

## 실습 1: ClusterIP (내부 접근)

백엔드 Pod 3개를 Deployment로 띄운다(각기 다른 IP를 가진다).

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl get pods -l app=web -o wide      # Pod별 IP 확인
```

Service로 노출한다(`kubectl expose`는 Deployment의 `app=web` 라벨을 셀렉터로 자동 사용).

```bash
kubectl expose deployment web --port=80 --target-port=80
kubectl get svc web                       # ClusterIP 확인
```

클러스터 안에서 DNS 이름으로 접근해 본다. 임시 Pod를 띄워 `web`을 호출한다.

```bash
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- wget -qO- web
```

nginx 기본 페이지 HTML이 돌아오면 성공이다. 요청할 때마다 3개 Pod 중 하나로 분산된다.

---

## 실습 2: NodePort (외부 접근)

`web-np.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-np
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080     # 30000–32767 범위
```

```bash
kubectl apply -f web-np.yaml
kubectl get svc web-np

# minikube가 접속 가능한 URL을 만들어 준다
minikube service web-np --url
```

출력된 `http://<노드IP>:30080` URL을 브라우저나 `curl`로 열면 nginx 페이지가 보인다.

---

## 정리

```bash
kubectl delete svc web web-np
kubectl delete deployment web
```

---

## 참고 링크

- Service: <https://kubernetes.io/ko/docs/concepts/services-networking/service/>
- DNS for Services: <https://kubernetes.io/ko/docs/concepts/services-networking/dns-pod-service/>
