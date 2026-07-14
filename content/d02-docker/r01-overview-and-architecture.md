
---

***index***

[1. Docker란](#1-docker란)  
[2. 컨테이너 vs VM](#2-컨테이너-vs-vm)  
[3. Docker Engine 계층 구조](#3-docker-engine-계층-구조)  
[4. containerd 내부 아키텍처](#4-containerd-내부-아키텍처)  
[5. OCI Runtime Spec의 config.json](#5-oci-runtime-spec의-configjson)  
[6. 생명주기: create와 start가 나뉜 이유](#6-생명주기-create와-start가-나뉜-이유)  
[7. runc가 루트 파일시스템을 바꾸는 방법](#7-runc가-루트-파일시스템을-바꾸는-방법)  
[8. OCI Image Spec 상세](#8-oci-image-spec-상세)  
[9. containerd-shim과 subreaper](#9-containerd-shim과-subreaper)  
[10. cgroup driver: cgroupfs와 systemd](#10-cgroup-driver-cgroupfs와-systemd)  
[11. 클라이언트-서버 모델과 REST API](#11-클라이언트-서버-모델과-rest-api)  
[12. docker 그룹의 위험성](#12-docker-그룹의-위험성)  
[13. 보안 사례 연구: CVE-2019-5736](#13-보안-사례-연구-cve-2019-5736)  
[14. 대안 런타임](#14-대안-런타임)  
[15. 실습](#15-실습)  
[16. 참고 링크](#16-참고-링크)

---

컨테이너는 새로운 커널 기능이 아니라 Namespace·cgroups·Capabilities·seccomp·overlayfs의 조합이다. Docker는 그 위에서 이미지 빌드·배포·실행을 다루는 도구다.



# 1. Docker란
---

컨테이너를 만들고 실행·배포하는 플랫폼이다. 이미지 빌드, 레지스트리 배포, 컨테이너 실행까지의 흐름을 다룬다.



# 2. 컨테이너 vs VM
---

VM은 하이퍼바이저 위에 각자 커널을 가진 게스트 OS를 통째로 띄우고, 컨테이너는 호스트 커널 하나를 공유하며 프로세스 단위로 격리한다.

```text
+-----------------+  +-----------------+
|      VM A       |  |      VM B       |
|  Guest OS + App |  |  Guest OS + App |
+-----------------+  +-----------------+
|              Hypervisor              |
+--------------------------------------+
|             Host OS / Kernel         |
+--------------------------------------+

+---------+  +---------+  +---------+
|Container|  |Container|  |Container|
|   App   |  |   App   |  |   App   |
+---------+  +---------+  +---------+
|            Docker Engine          |
+-----------------------------------+
|         Host OS Kernel (공유)      |
+-----------------------------------+
```

컨테이너는 커널 부팅이 없고 프로세스 하나를 fork+exec하는 수준이라 기동이 빠르고 오버헤드가 작다. 대신 호스트와 커널을 공유하므로 커널 취약점이 곧 컨테이너 탈출 경로가 될 수 있다.



# 3. Docker Engine 계층 구조
---

```text
docker CLI --(REST API)--> dockerd --> containerd --> containerd-shim --> runc --> 컨테이너 프로세스
```

| 구성요소 | 역할 |
| :-- | :-- |
| docker CLI | 사용자가 입력하는 명령. REST API로 dockerd에 요청만 전달 |
| dockerd | 이미지 빌드, 네트워크·Volume 관리, API 서버 |
| containerd | 컨테이너 생명주기(이미지 pull, 생성·시작·정지)를 실제로 수행. Docker와 독립적으로 쓰이는 CNCF 프로젝트로, Kubernetes의 기본 컨테이너 런타임이기도 하다 |
| containerd-shim | 컨테이너마다 하나씩 붙는 얇은 프로세스. runc가 컨테이너를 만들고 빠진 뒤 이 shim이 부모로 남는다 |
| runc | OCI Runtime Spec을 구현한 저수준 실행기. Namespace·cgroups·Capabilities를 실제로 설정해 컨테이너 프로세스를 실행한다 |

각 층은 서로 다른 관심사를 책임진다 — dockerd는 사용자 경험, containerd는 생명주기와 이미지 관리, runc는 커널과의 마지막 접점을 맡는다.



# 4. containerd 내부 아키텍처
---

containerd는 단일 모놀리식 데몬이 아니라 gRPC API 뒤에 붙은 플러그인들의 조합이다. "containerd has a smart client architecture" — 데몬이 꼭 갖고 있지 않아도 되는 기능(이미지 빌드 등)은 클라이언트(dockerd, BuildKit) 쪽 책임으로 넘긴다.

| 구성요소 | 플러그인 ID | 역할 |
| :-- | :-- | :-- |
| Content store | `io.containerd.content.v1` | 이미지 레이어·매니페스트를 SHA256 digest로 식별되는 불변 블롭으로 저장(content-addressable storage). 같은 레이어를 여러 이미지가 공유해도 디스크엔 한 번만 저장 |
| Snapshotter | `io.containerd.snapshotter.v1`(overlayfs 등) | 레이어를 lowerdir·upperdir 구조의 실제 마운트 가능한 파일시스템 뷰로 조립 |
| Metadata store | `io.containerd.metadata.v1`(bolt) | 이미지·컨테이너·스냅샷 메타데이터를 BoltDB(Go로 짠 임베디드 key-value 저장소)에 보관 |
| Runtime shim | `io.containerd.runtime.v2` | 컨테이너별 shim 프로세스를 통해 runc를 호출하고 생명주기를 관리 |

```bash
sudo ctr plugins ls                                                        # containerd 자체 CLI로 로드된 플러그인 확인
sudo ls /var/lib/containerd/io.containerd.content.v1.content/blobs/sha256/ | head   # digest로 저장된 블롭들
sudo ls /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/        # 레이어별 스냅샷
```



# 5. OCI Runtime Spec의 config.json
---

runc가 컨테이너를 만들 때 참조하는 설계도가 `config.json`이다. OCI Runtime Spec이 이 파일의 형식을 표준화한다.

| 필드 | 역할 |
| :-- | :-- |
| `ociVersion` | 스펙 버전(SemVer) |
| `process` | 실행할 프로그램·인자·환경변수·작업 디렉터리·터미널 여부 |
| `root` | 컨테이너 루트 파일시스템 경로와 읽기 전용 여부 |
| `mounts` | root 외 추가로 마운트할 지점들의 배열 |
| `hostname`/`domainname` | UTS Namespace 안에서 보일 호스트명 |
| `hooks` | 생명주기 이벤트(`createRuntime`·`prestart`·`poststart`·`poststop`) 전후로 실행할 외부 프로그램 |
| `linux.namespaces` | 8종 Namespace 각각 새로 만들지, 기존 것을 재사용할지 |
| `linux.resources` | cgroup 리소스 제한(메모리·CPU·블록 I/O) |
| `linux.capabilities` | Capabilities 5개 집합(effective·bounding·permitted·inheritable·ambient)별 목록 |
| `linux.seccomp` | syscall 필터 규칙 |
| `linux.maskedPaths`/`readonlyPaths` | 컨테이너 안에서 숨기거나 읽기 전용으로 만들 경로(`/proc/kcore` 등을 가림) |

Namespace·cgroups·Capabilities·seccomp 설정을 JSON 하나로 모아 커널에 그대로 요청하는 문서다. `docker run`의 `--cap-add`·`--memory`·`--security-opt seccomp` 옵션은 결국 이 JSON의 해당 필드를 채우는 것에 지나지 않는다.

```bash
docker run -d --name tempweb nginx:alpine
CID=$(docker inspect -f '{{.Id}}' tempweb)
sudo find /run/containerd/io.containerd.runtime.v2.task -name config.json -path "*${CID}*" \
  -exec python3 -m json.tool {} \; | head -50
```



# 6. 생명주기: create와 start가 나뉜 이유
---

OCI Runtime Spec은 컨테이너 상태를 `creating` → `created` → `running` → `stopped` 네 단계로 정의하고, `create`와 `start`를 별개 명령으로 못박는다. `create` 단계에서 Namespace·cgroup·마운트·루트 파일시스템까지 전부 구성되지만, `process.args`로 지정한 실제 프로그램은 아직 실행되지 않는다.

이 간극은 컨테이너의 Network Namespace가 다 준비된 뒤에도 외부(CNI 플러그인 등)가 그 안에 네트워크 인터페이스를 설정할 시간을 벌어준다. Kubernetes가 Pod를 띄울 때 "네트워크가 붙기 전에 앱이 먼저 실행되는" 경쟁 상태를 막는 설계이기도 하다.

```bash
runc create --bundle /path/to/bundle mycontainer    # created 상태. 프로세스는 아직 안 뜸
runc state mycontainer                                 # status: created
runc start mycontainer                                  # 이제 process.args 실행
```



# 7. runc가 루트 파일시스템을 바꾸는 방법
---

runc는 컨테이너의 루트 파일시스템을 바꿀 때 `chroot(2)` 대신 `pivot_root(2)`를 쓴다. `chroot`는 프로세스가 보는 `/`만 바꿀 뿐 이전 루트 마운트가 마운트 네임스페이스 안에 그대로 남아 있어, 조작에 따라 그 이전 루트로 다시 빠져나갈 여지가 남는다. `pivot_root`는 새 루트와 이전 루트를 맞바꾸고, 이전 루트를 새 루트 아래 지점으로 옮긴 뒤 그 지점을 즉시 `umount`해버려 돌아갈 길 자체를 없앤다.

```text
1. unshare(CLONE_NEWNS)             # 이 프로세스만의 Mount Namespace 생성
2. mount(new_root, MS_BIND)          # 새 루트를 자기 자신에 bind mount(pivot_root 전제조건)
3. pivot_root(new_root, put_old)      # 루트 교체 + 이전 루트를 put_old로 이동
4. chdir("/")
5. umount2(put_old, MNT_DETACH)       # 이전 루트로 가는 마운트 자체를 제거
6. rmdir(put_old)
```

이 순서는 Mount Namespace가 프로세스마다 독립된 마운트 목록을 가질 수 있어서 가능하다.



# 8. OCI Image Spec 상세
---

이미지는 계층화된 JSON 문서 세 겹으로 이뤄진다.

```text
manifest.json ─(config 참조)→ config.json (실행 환경: Env, Entrypoint, Cmd, ...)
              ─(layers 참조)→ layer.tar.gz × N (실제 파일 diff)
```

`manifest.json`의 `layers` 배열은 각 항목이 `mediaType`(예: `application/vnd.oci.image.layer.v1.tar+gzip`)·`digest`(SHA256)·`size`를 갖는 descriptor다. 모든 요소가 SHA256 digest로 식별되는 content-addressable storage라, 같은 베이스 이미지를 쓰는 여러 이미지는 그 레이어를 디스크에 중복 저장하지 않는다.

레이어 tar 안에서 파일이 "삭제됐다"는 사실은 특수한 **whiteout 파일**(`.wh.<파일명>`)로 표현한다 — 하위 레이어의 파일을 실제로 지울 수는 없으니(읽기 전용) 상위 레이어에 이 마커 파일을 둬서 overlay filesystem이 합성 뷰를 만들 때 그 이름을 가려버리게 하는 것이다.

```bash
docker save nginx:alpine -o nginx.tar
mkdir nginx-extract && tar xf nginx.tar -C nginx-extract
python3 -m json.tool nginx-extract/manifest.json
find nginx-extract -name '*.tar' -exec tar tvf {} \; | grep '\.wh\.' | head
```



# 9. containerd-shim과 subreaper
---

컨테이너마다 붙는 `containerd-shim-runc-v2` 프로세스는 runc가 컨테이너를 만들고 빠져나간 뒤 그 프로세스의 부모로 남는다. dockerd·containerd를 재시작(패키지 업데이트 등)해도 이미 떠 있는 컨테이너가 죽지 않는 이유가 이 구조 덕분이다 — shim은 dockerd·containerd와 별도 프로세스라 상위 데몬만 내렸다 올려도 컨테이너는 계속 돈다.

shim은 subreaper 역할도 겸한다. 컨테이너 안 PID 1이 자신의 자식을 제대로 회수(`wait()`)하지 못하면, 고아가 된 프로세스는 컨테이너의 PID Namespace를 벗어나 shim에 재연결되고 shim이 대신 회수한다.



# 10. cgroup driver: cgroupfs와 systemd
---

컨테이너의 cgroup을 실제로 만드는 방법이 두 가지다.

| 드라이버 | 동작 |
| :-- | :-- |
| cgroupfs | 런타임이 `/sys/fs/cgroup` 아래 직접 디렉터리를 만들고 파일을 쓰는 저수준 방식 |
| systemd | 런타임이 systemd에 위임해 `.slice`·`.scope` unit으로 cgroup을 만들게 하는 방식 |

systemd가 PID 1인 호스트에서 cgroupfs 드라이버를 쓰면, systemd와 컨테이너 런타임이 **서로 다른 두 개의 cgroup 관리자**로 같은 트리를 각자 다르게 인식하게 된다 — 자원 압박 상황에서 두 관리자의 판단이 어긋나 노드가 불안정해질 수 있다. Kubernetes 공식 문서도 kubelet과 컨테이너 런타임의 cgroup driver를 반드시 `systemd`로 일치시키라고 명시한다(kubeadm v1.22부터 기본값이 systemd로 바뀐 이유이기도 하다).

```bash
docker info | grep -i cgroup
cat /etc/docker/daemon.json    # "exec-opts": ["native.cgroupdriver=systemd"] 로 명시 가능
```



# 11. 클라이언트-서버 모델과 REST API
---

`docker` CLI는 자체적으로 아무 일도 하지 않는다. 유닉스 소켓(`/var/run/docker.sock`)으로 dockerd에 REST API 요청을 보낼 뿐이다.

```bash
curl --unix-socket /var/run/docker.sock http://localhost/containers/json
```

이 소켓에 접근할 수 있느냐가 곧 dockerd에 대한 권한 전체를 뜻한다.



# 12. docker 그룹의 위험성
---

`docker` 그룹에 사용자를 넣으면 `sudo` 없이 docker 명령을 쓸 수 있게 된다. dockerd는 root 권한으로 돌고, 그 소켓에 접근할 수 있는 사람은 사실상 호스트 root와 동급이다 — 볼륨 마운트로 호스트 루트를 그대로 컨테이너에 붙이고 그 안에서 마음대로 조작할 수 있기 때문이다.

```bash
docker run -v /:/host -it alpine chroot /host
```

이 한 줄이면 `docker` 그룹 구성원이 호스트 파일시스템 전체에 root로 접근한다. setuid 위험과 본질적으로 같은 권한 상승 벡터라, `docker` 그룹에 넣는 것은 `sudo ALL=(ALL) NOPASSWD: ALL`을 주는 것과 크게 다르지 않다. rootless 모드가 이 문제를 근본적으로 피하는 방법이다.



# 13. 보안 사례 연구: CVE-2019-5736
---

2019년 발견된 runc 컨테이너 탈출 취약점이다(CVSS 8.6, Docker 18.09.2 미만·runc 1.0-rc6 이하 영향). 공격자가 root로 명령을 실행할 수 있는 컨테이너 — 직접 만든 악성 이미지를 새로 실행하거나, 이미 쓰기 권한이 있는 기존 컨테이너에 `docker exec`로 접속하는 두 경로 모두 가능 — 에서, `/proc/self/exe` 관련 파일 디스크립터 처리 결함을 이용해 **호스트의 runc 바이너리 자체를 덮어써** 호스트 root 권한을 얻는다.

`exec`가 새 프로세스를 컨테이너의 Namespace 안으로 밀어 넣는 과정에서, runc 자신의 실행 파일을 가리키는 파일 디스크립터가 아주 짧은 순간 컨테이너 프로세스가 조작 가능한 상태로 노출된 것이 근본 원인이었다. 다음에 호스트에서 `runc`(또는 그걸 부르는 dockerd)가 실행될 때마다, 실은 공격자가 덮어쓴 바이너리가 호스트 root 권한으로 돈다.

컨테이너는 호스트 커널과, 이 경우엔 호스트의 런타임 바이너리까지 공유하는 경계다. rootless·`userns-remap`·seccomp 같은 방어선을 겹겹이 두는 게 단일 실패점에 기대지 않는 방법이다.



# 14. 대안 런타임
---

| 런타임 | 특징 |
| :-- | :-- |
| Podman | 데몬 없이(daemonless) 동작. 기본이 rootless. Docker CLI와 거의 동일한 명령 |
| containerd (단독) | dockerd 없이 컨테이너 실행만 담당. Kubernetes의 기본 CRI 런타임 |
| CRI-O | Kubernetes 전용으로 만들어진 경량 런타임 |

Kubernetes는 애초에 Docker 자체가 아니라 containerd·CRI-O 같은 CRI(Container Runtime Interface) 구현체를 직접 쓴다.



# 15. 실습
---

```bash
systemctl status docker
ps -ef | grep -E 'containerd|runc' | grep -v grep

# 컨테이너 하나 띄우고 shim 확인
docker run -d --name tempweb nginx:alpine
ps -ef | grep containerd-shim

# runc가 실제로 참조한 config.json 들여다보기
CID=$(docker inspect -f '{{.Id}}' tempweb)
sudo find /run/containerd/io.containerd.runtime.v2.task -name config.json -path "*${CID}*" \
  -exec python3 -m json.tool {} \; | grep -A5 '"namespaces"'

# 이미지 매니페스트와 whiteout 파일 확인
docker save nginx:alpine -o nginx.tar
mkdir -p nginx-extract && tar xf nginx.tar -C nginx-extract
python3 -m json.tool nginx-extract/manifest.json

# cgroup driver 확인
docker info | grep -i cgroup

docker rm -f tempweb
```



# 16. 참고 링크
---

─ OCI Runtime Specification: config.json — <https://github.com/opencontainers/runtime-spec/blob/main/config.md>  
─ OCI Runtime Specification: 생명주기 — <https://github.com/opencontainers/runtime-spec/blob/main/runtime.md>  
─ OCI Image Specification: manifest — <https://github.com/opencontainers/image-spec/blob/main/manifest.md>  
─ pivot_root(2) — <https://man7.org/linux/man-pages/man2/pivot_root.2.html>  
─ containerd Plugins — <https://github.com/containerd/containerd/blob/main/docs/PLUGINS.md>  
─ NVD: CVE-2019-5736 — <https://nvd.nist.gov/vuln/detail/CVE-2019-5736>
