# 준비 과정

쿠버네티스 실습 환경 구성. 실습은 **Linux(x86-64)** 기준, 로컬에 **노드 3개짜리 단일 클러스터**를 minikube[^minikube]로 구성한다.

---

## 왜 쿠버네티스인가

- 컨테이너는 어디서든 똑같이 실행되는 격리된 프로세스다.
- 수가 수십~수백 개로 늘면 배치·복구·확장·연결을 사람이 관리할 수 없다.
- 쿠버네티스(k8s)가 이 일을 자동화한다.

즉, 쿠버네티스는 "컨테이너를 대신 운영하는 시스템"이다.

---

## 핵심 용어

| 용어 | 설명 |
|:-----|:-----|
| **컨테이너** | 격리되어 실행되는 애플리케이션 프로세스. Pod의 재료. |
| **이미지** | 컨테이너의 설계도(스냅샷). 예: `nginx:1.27` |
| **노드(Node)** | 컨테이너가 실행되는 서버 1대(물리/가상). |
| **클러스터(Cluster)** | 여러 노드를 묶은 전체. 쿠버네티스가 관리하는 단위. |
| **컨트롤 플레인** | 클러스터의 두뇌. 무엇을 어디에 띄울지 결정. |
| **kubelet** | 각 노드에서 컨트롤 플레인 지시대로 컨테이너를 띄우는 에이전트. |
| **kubectl** | 클러스터에 명령을 내리는 CLI. |

---

## 1. Docker 설치 (dnf)

minikube가 이 Docker 위에 노드(컨테이너)를 올린다. Docker 공식 저장소를 등록해 설치한다.

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

## 2. kubectl 설치 (dnf)

쿠버네티스 공식 RPM 저장소를 등록한다. `v1.31`은 원하는 마이너 버전으로 맞춘다.

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

## 3. minikube 설치 (dnf)

minikube는 위 저장소에 없으므로 공식 RPM으로 설치한다.

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
sudo dnf install -y ./minikube-latest.x86_64.rpm
```

## 4. 노드 3개 클러스터 시작

```bash
# 컨트롤 플레인 1 + 워커 2 = 총 3노드
minikube start --nodes=3 --driver=docker
```

> 각 노드는 실제 서버가 아니라 로컬 컨테이너다. 3노드는 최소 4GB, 여유 있게 6~8GB RAM을 쓴다.

## 5. 확인

```bash
kubectl get nodes
```

```text
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   1m    v1.31.0
minikube-m02   Ready    <none>          1m    v1.31.0
minikube-m03   Ready    <none>          1m    v1.31.0
```

---

## 자주 쓰는 명령

```bash
kubectl get <리소스>              # 목록 (예: kubectl get pods)
kubectl describe <리소스> <이름>  # 상세 정보/이벤트
kubectl logs <pod>                # 로그
kubectl exec -it <pod> -- sh      # 컨테이너 셸 진입
kubectl apply -f <파일.yaml>      # YAML로 생성/갱신
kubectl delete <리소스> <이름>    # 삭제
```

---

## 정리

```bash
minikube stop      # 정지(상태 보존)
minikube delete    # 완전 삭제
```

---

## 참고

- kubectl 설치: <https://kubernetes.io/docs/tasks/tools/>
- minikube: <https://minikube.sigs.k8s.io/docs/start/>
- 다음 문서: [Pod](/kubernetes/Pod/)

[^minikube]: 로컬 PC에 연습용 쿠버네티스 클러스터를 손쉽게 띄워 주는 도구. 실제 서버 여러 대 대신 노드를 컨테이너(또는 VM)로 만든다.
