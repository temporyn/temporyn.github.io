
---

***index***

[1. 용어](#1-용어)  
[2. 쿠버네티스 기본구조](#2-쿠버네티스-기본구조)  
─ [Control Plane 컴포넌트](#control-plane-컴포넌트)  
─ [노드 컴포넌트](#노드-컴포넌트)  
[3. Docker 설치 (dnf)](#3-docker-설치-dnf)  
[4. kubectl 설치 (dnf)](#4-kubectl-설치-dnf)  
[5. minikube 설치 (dnf)](#5-minikube-설치-dnf)  
[6. 노드 3개 클러스터 시작](#6-노드-3개-클러스터-시작)  
[7. 확인](#7-확인)  
[8. 자주 쓰는 명령](#8-자주-쓰는-명령)  
[9. minikube 정리](#9-minikube-정리)  
[10. 참고 링크](#10-참고-링크)

---

로컬 쿠버네티스 실습 환경. **Linux(x86-64)** 에 minikube[^minikube]로 **노드 3개짜리 단일 클러스터**를 올린다.

> 컨테이너가 수십~수백 개로 늘면 배치·복구·확장·연결을 손으로 못 한다. 그걸 대신 운영하는 게 쿠버네티스(k8s).


# 1. 용어
---

| 용어                | 설명                                        |
| :---------------- | :---------------------------------------- |
| **컨테이너**          | 격리되어 실행되는 애플리케이션 프로세스. Pod의 재료.           |
| **이미지**           | 컨테이너의 설계도(스냅샷). 예: `nginx:1.27`           |
| **노드(Node)**      | 컨테이너가 실행되는 서버 1대(물리/가상).                  |
| **클러스터(Cluster)** | 여러 노드를 묶은 전체. 쿠버네티스가 관리하는 단위.             |
| **Control Plane** | 클러스터의 두뇌. 무엇을 어디에 띄울지 결정.                 |
| **kubelet**       | 각 노드에서 Control Plane 지시대로 컨테이너를 띄우는 에이전트. |
| **kubectl**       | 클러스터에 명령을 내리는 CLI.                        |



# 2. 쿠버네티스 기본구조
---
클러스터는 **Control Plane**과 **Worker Node**로 나뉜다. Control Plane이 무엇을 어디에 띄울지 결정하고, Worker Node가 실제로 컨테이너(Pod)를 실행한다. `kubectl`은 Control Plane의 API 서버에만 요청하며, 원하는 상태를 저장해 두면 각 컴포넌트가 현재 상태를 그 상태로 맞춘다.

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



# 3. Docker 설치 (dnf)
---

minikube가 이 Docker 위에 노드를 컨테이너로 띄운다. 공식 저장소 등록 후 설치.

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io

# 데몬 시작 + 부팅 시 자동 실행
sudo systemctl enable --now docker

# sudo 없이 docker 실행 (그룹 반영은 재로그인 후)
sudo usermod -aG docker $USER
```

확인:

```bash
docker run --rm hello-world
```



# 4. kubectl 설치 (dnf)
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



# 5. minikube 설치 (dnf)
---
위 저장소엔 없으므로 공식 RPM으로.

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
sudo dnf install -y ./minikube-latest.x86_64.rpm
```



# 6. 노드 3개 클러스터 시작
---

```bash
# Control Plane 1 + Worker 2 = 총 3노드
minikube start --nodes=3 --driver=docker
```

> 각 노드는 실제 서버가 아니라 로컬 컨테이너. 3노드는 최소 4GB, 여유 있게 6~8GB RAM.



# 7. 확인
---
```bash
kubectl get nodes
```

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   1m    v1.31.0
minikube-m02   Ready    <none>          1m    v1.31.0
minikube-m03   Ready    <none>          1m    v1.31.0
```



# 8. 자주 쓰는 명령
---

```bash
kubectl get <리소스>              # 목록 (예: kubectl get pods)
kubectl describe <리소스> <이름>  # 상세 정보/이벤트
kubectl logs <pod>                # 로그
kubectl exec -it <pod> -- sh      # 컨테이너 셸 진입
kubectl apply -f <파일.yaml>      # YAML로 생성/갱신
kubectl delete <리소스> <이름>    # 삭제
```



# 9. minikube 정리
---

```bash
minikube stop      # 정지(상태 보존)
minikube delete    # 완전 삭제
```



# 10. 참고 링크
---

kubectl 설치 — <https://kubernetes.io/docs/tasks/tools/>

minikube — <https://minikube.sigs.k8s.io/docs/start/>

다음 문서 — [Pod](/kubernetes/pod/)

[^minikube]: 로컬 PC에 연습용 쿠버네티스 클러스터를 손쉽게 띄워 주는 도구. 실제 서버 여러 대 대신 노드를 컨테이너(또는 VM)로 만든다.
