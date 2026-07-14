
---

***index***

[1. 용어](#1-용어)  
[2. 쿠버네티스 기본구조](#2-쿠버네티스-기본구조)  
─ [Control Plane 컴포넌트](#control-plane-컴포넌트)  
─ [노드 컴포넌트](#노드-컴포넌트)  
[3. kube-apiserver 요청 처리 파이프라인](#3-kube-apiserver-요청-처리-파이프라인)  
[4. etcd: Raft와 MVCC](#4-etcd-raft와-mvcc)  
[5. kube-scheduler: Filtering과 Scoring](#5-kube-scheduler-filtering과-scoring)  
[6. kube-controller-manager와 reconciliation loop](#6-kube-controller-manager와-reconciliation-loop)  
[7. kubelet과 CRI](#7-kubelet과-cri)  
[8. kube-proxy 모드](#8-kube-proxy-모드)  
[9. Docker 설치 (dnf)](#9-docker-설치-dnf)  
[10. kubectl 설치 (dnf)](#10-kubectl-설치-dnf)  
[11. minikube 설치 (dnf)](#11-minikube-설치-dnf)  
[12. 노드 3개 클러스터 시작](#12-노드-3개-클러스터-시작)  
[13. 확인](#13-확인)  
[14. 자주 쓰는 명령](#14-자주-쓰는-명령)  
[15. minikube 정리](#15-minikube-정리)  
[16. 참고 링크](#16-참고-링크)

---

로컬 쿠버네티스 실습 환경. **Linux(x86-64)** 에 minikube[^minikube]로 **노드 3개짜리 단일 클러스터**를 올린다.

> 컨테이너가 수십~수백 개로 늘면 배치·복구·확장·연결을 손으로 못 한다. 그걸 대신 운영하는 게 쿠버네티스(k8s).


# 1. 용어
---

| 용어                | 설명                                        |
| :---------------- | :---------------------------------------- |
| **컨테이너**          | 격리되어 실행되는 애플리케이션 프로세스. Pod의 재료.           |
| **Pod**            | 컨테이너 하나 이상을 묶어 함께 배치·실행하는 쿠버네티스 최소 배포 단위. |
| **이미지**           | 컨테이너의 설계도(스냅샷). 예: `nginx:1.27`           |
| **노드(Node)**      | 컨테이너가 실행되는 서버 1대(물리/가상).                  |
| **클러스터(Cluster)** | 여러 노드를 묶은 전체. 쿠버네티스가 관리하는 단위.             |
| **Control Plane** | 클러스터의 두뇌. 무엇을 어디에 띄울지 결정.                 |
| **kubelet**       | 각 노드에서 Control Plane 지시대로 컨테이너를 띄우는 에이전트. |
| **kubectl**       | 클러스터에 명령을 내리는 CLI.                        |



# 2. 쿠버네티스 기본구조
---

클러스터는 **Control Plane**과 **Worker Node**로 나뉜다. Control Plane이 무엇을 어디에 띄울지 결정하고, Worker Node가 실제로 Pod(컨테이너 하나 이상을 묶은 단위)를 실행한다. `kubectl`은 Control Plane의 API 서버에만 요청하며, 원하는 상태를 저장해 두면 각 컴포넌트가 현재 상태를 그 상태로 맞춘다.

```text
             +-----------------------------------+
             |           Control Plane           |
             |                                   |
kubectl ---->|  kube-apiserver <--> etcd         |
             |       |                           |
             |       +-- kube-scheduler          |
             |       +-- kube-controller-manager |
             +-----------------+-----------------+
                               |
                    +----------+----------+
                    |                     |
            +-------+-------+     +-------+-------+
            |  Worker Node  |     |  Worker Node  |
            |               |     |               |
            |  kubelet      |     |  kubelet      |
            |  kube-proxy   |     |  kube-proxy   |
            |  runtime      |     |  runtime      |
            |  +---------+  |     |  +---------+  |
            |  |  Pods   |  |     |  |  Pods   |  |
            |  +---------+  |     |  +---------+  |
            +---------------+     +---------------+
```

→ kubectl 요청은 API 서버로 들어가고, scheduler가 Pod를 노드에 배정하면 그 노드의 kubelet이 컨테이너를 띄운다.

## Control Plane 컴포넌트

클러스터의 두뇌. 대개 별도 노드에서 돈다.

| 컴포넌트 | 역할 |
|:---------|:-----|
| **kube-apiserver** | 클러스터의 정문. kubectl·내부 컴포넌트의 모든 요청이 거치는 REST API. |
| **etcd** | 클러스터의 모든 상태를 담는 key-value 저장소. 사실상 유일한 원본. |
| **kube-scheduler** | 아직 노드가 정해지지 않은 Pod를 조건에 맞는 노드에 배정. |
| **kube-controller-manager** | 여러 controller를 돌려 현재 상태를 원하는 상태로 수렴시킴. |
| **cloud-controller-manager** | 클라우드 연동(로드밸런서·Volume 등). 선택 — 로컬 minikube엔 없음. |

## 노드 컴포넌트

모든 Worker Node에서 돈다. Pod가 실제로 실행되는 곳.

| 컴포넌트 | 역할 |
|:---------|:-----|
| **kubelet** | 각 노드의 에이전트. 배정된 Pod의 컨테이너를 띄우고 상태를 보고. |
| **kube-proxy** | Service로 온 트래픽을 실제 Pod로 넘기는 네트워크 규칙 관리. 선택 — CNI가 대체하기도. |
| **컨테이너 런타임** | 실제로 컨테이너를 실행하는 소프트웨어(containerd 등). |

minikube는 이 구조를 로컬 Docker 컨테이너로 재현한다. `minikube start --nodes=3`은 노드 하나(`minikube`)에 Control Plane을 올리고 Worker Node 2개(`minikube-m02`·`minikube-m03`)를 더해 총 3노드를 만든다.



# 3. kube-apiserver 요청 처리 파이프라인
---

모든 요청은 세 단계를 순서대로 거쳐야 etcd에 반영된다.

**Authentication** — 클라이언트 인증서, Bearer 토큰(ServiceAccount 토큰 등), Webhook 등 여러 방식을 동시에 설정할 수 있고, 그중 하나라도 성공하면 통과한다(단락 평가). 성공하면 Username·UID·Groups가 확정되고, 실패하면 401을 반환한다.

**Authorization** — 인증된 주체가 그 리소스에 그 동작을 할 권한이 있는지 판정한다. RBAC이 가장 흔히 쓰이고, Node Authorization·Webhook·ABAC도 있다. 실패하면 403을 반환한다.

**Admission Control** — 통과한 요청을 검증·변형하는 마지막 단계다. Mutating admission(기본값 주입 등)이 먼저 돌고, 그 결과를 Validating admission(ResourceQuota·LimitRanger·PodSecurity 등)이 검사한다. Webhook 기반 커스텀 admission도 이 단계에 낀다.

세 단계를 전부 통과한 요청만 etcd에 실제로 기록된다.



# 4. etcd: Raft와 MVCC
---

클러스터의 모든 상태가 저장되는 단일 진실 공급원이다. 여러 etcd 노드가 **Raft** 합의 알고리즘으로 서로 복제되며, 과반수(quorum)가 동의해야 쓰기가 확정된다 — 노드 5개 중 2개가 죽어도(과반 3개 생존) 클러스터는 계속 쓰기를 받지만, 과반이 죽으면 쓰기 자체가 멈춘다.

데이터는 **MVCC**(다중 버전 동시성 제어) 모델로 저장된다. 값을 바꿀 때마다 이전 값을 지우지 않고 새 **revision**을 만들어 과거 버전을 유지한다 — kube-apiserver의 watch가 "특정 revision 이후의 변경만" 스트리밍으로 받을 수 있는 근거가 이 구조다. 물리적으로는 revision 델타를 담는 B+ tree(영구 저장)와 키 조회를 빠르게 하는 in-memory B-tree(인덱스) 두 계층으로 구현된다.



# 5. kube-scheduler: Filtering과 Scoring
---

아직 노드가 정해지지 않은 Pod마다 두 단계를 거친다.

**Filtering**(과거 이름 predicates) — 전체 노드 중 이 Pod가 뜰 수 있는 노드만 추린다. 리소스 부족, taint 불일치 등으로 못 뜨는 노드는 이 단계에서 제외된다.

**Scoring**(과거 이름 priorities) — Filtering을 통과한 노드마다 점수를 매겨 가장 높은 노드를 고른다. 동점이면 무작위로 선택한다.

Filtering을 통과하는 노드가 하나도 없으면 Pod는 배정되지 못한 채 `Pending` 상태로 남고, `FailedScheduling` 이벤트가 기록된다. 이 경우 스케줄러는 우선순위(Priority)가 낮은 다른 Pod를 쫓아내는 **preemption**으로 빈 자리를 만들어 재시도하기도 한다.

최신 스케줄러는 이 단계들을 `QueueSort`·`Filter`·`Score`·`Reserve`·`Permit`·`Bind` 같은 플러그인 확장점으로 세분화한 **Scheduling Framework**로 구현한다.



# 6. kube-controller-manager와 reconciliation loop
---

Deployment·ReplicaSet 같은 워크로드 controller가 이 프로세스 안에서 함께 돈다. 각 controller는 API 서버를 매번 폴링하는 대신 **watch**로 변경 이벤트를 스트리밍 받아 로컬 캐시(informer)에 반영한다. 캐시가 실제 상태와 어긋날 가능성에 대비해 일정 주기(resync period)마다 전체를 다시 훑기도 한다. reconciliation loop는 이 이벤트가 올 때마다 "현재 상태(캐시) vs 원하는 상태(spec)"를 비교해 차이를 좁히는 동작을 반복한다.



# 7. kubelet과 CRI
---

각 노드에서 배정된 Pod를 실제로 실행하는 에이전트다. 컨테이너를 직접 만들지 않고 **CRI**(Container Runtime Interface)라는 gRPC 인터페이스로 컨테이너 런타임에 요청하며, 그 요청을 containerd 같은 런타임이 받아 실제 컨테이너를 만든다. kubelet은 주기적으로 컨테이너 상태를 폴링하는 **PLEG**(Pod Lifecycle Event Generator)로 변경을 감지해 Pod 상태를 갱신한다.



# 8. kube-proxy 모드
---

Service로 들어온 트래픽을 실제 Pod로 넘기는 규칙을 관리한다. 구현 방식이 세 가지다.

| 모드 | 특징 |
| :-- | :-- |
| iptables (기본) | Service 수에 비례해 규칙 개수가 늘어 대규모 클러스터에서 느려짐 |
| ipvs | 커널의 IP Virtual Server를 사용. 해시 테이블 기반이라 대규모에서도 빠름 |
| nftables | iptables의 커널 후속 프레임워크 기반. 최신 |

minikube는 별도 지정이 없으면 기본 모드로 동작한다.



# 9. Docker 설치 (dnf)
---

minikube가 이 Docker 위에 노드를 컨테이너로 띄운다. 공식 저장소 등록 후 설치한다.

```bash
sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 데몬 시작 + 부팅 시 자동 실행
sudo systemctl enable --now docker
```

확인(sudo로 실행 — group 반영 여부와 무관하게 재현됨):

```bash
sudo docker run --rm hello-world
```

sudo 없이 `docker` 명령을 쓰려면 현재 사용자를 `docker` 그룹에 추가한다.

```bash
sudo usermod -aG docker $USER
newgrp docker                # 현재 셸에 즉시 반영(또는 로그아웃 후 재로그인)
docker run --rm hello-world  # group 반영 후에는 sudo 없이 동작
```

`usermod -aG` 직후 새 그룹은 **즉시 반영되지 않는다**. `newgrp` 또는 재로그인 없이 바로 `docker run`을 실행하면 `permission denied`로 실패한다 — Heading.11 이후 minikube 명령도 이 그룹이 반영된 셸에서 실행해야 한다.



# 10. kubectl 설치 (dnf)
---

쿠버네티스 공식 RPM 저장소 등록. `v1.31`은 원하는 마이너 버전으로.

```bash
cat <<'EOF' | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

sudo dnf install -y kubectl
kubectl version --client
```



# 11. minikube 설치 (dnf)
---
위 저장소엔 없으므로 공식 RPM으로.

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
sudo dnf install -y ./minikube-latest.x86_64.rpm
```



# 12. 노드 3개 클러스터 시작
---

```bash
# Control Plane 1 + Worker 2 = 총 3노드
minikube start --nodes=3 --driver=docker
```

> 각 노드는 실제 서버가 아니라 로컬 컨테이너. minikube 공식 최소 요구사항은 노드 1개 기준 2GB RAM이고 3-node 전용 공식 가이드는 없다 — 단순히 3배 하면 6GB 안팎이 필요하다는 계산이 나온다(미검증 추정치). 여유 있게 8GB 이상을 권장한다.

메모리가 부족하면 일부 노드가 `NotReady`에서 멈추거나 컨테이너가 OOM으로 재시작을 반복한다. 이 경우 `minikube logs`와 `kubectl describe node <노드이름>`으로 원인을 확인한다.



# 13. 확인
---
```bash
kubectl get nodes
```

예시 출력(실제 AGE·버전은 실행 시점·minikube 버전에 따라 달라진다):

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   1m    v1.31.0
minikube-m02   Ready    <none>          1m    v1.31.0
minikube-m03   Ready    <none>          1m    v1.31.0
```



# 14. 자주 쓰는 명령
---

```bash
kubectl get <리소스>              # 목록 (예: kubectl get pods)
kubectl describe <리소스> <이름>  # 상세 정보/이벤트
kubectl logs <pod>                # 로그
kubectl exec -it <pod> -- sh      # 컨테이너 셸 진입
kubectl apply -f <파일.yaml>      # YAML로 생성/갱신
kubectl delete <리소스> <이름>    # 삭제
```



# 15. minikube 정리
---

```bash
minikube stop      # 정지(상태 보존)
minikube delete    # 완전 삭제
```



# 16. 참고 링크
---

─ Kubernetes Components — <https://kubernetes.io/docs/concepts/overview/components/>  
─ Authenticating — <https://kubernetes.io/docs/reference/access-authn-authz/authentication/>  
─ kube-scheduler — <https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/>  
─ etcd Data Model — <https://etcd.io/docs/v3.6/learning/data_model/>  
─ kubectl 설치 — <https://kubernetes.io/docs/tasks/tools/>  
─ minikube — <https://minikube.sigs.k8s.io/docs/start/>  
─ 다음 문서 — [Pod](/kubernetes/pod/)

[^minikube]: 로컬 PC에 연습용 쿠버네티스 클러스터를 손쉽게 띄워 주는 도구. 실제 서버 여러 대 대신 노드를 컨테이너(또는 VM)로 만든다.
