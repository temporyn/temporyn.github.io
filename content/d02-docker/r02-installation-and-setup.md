
---

***index***

[1. 설치 (dnf)](#1-설치-dnf)  
[2. rootful 기본 구성](#2-rootful-기본-구성)  
[3. daemon.json 설정](#3-daemonjson-설정)  
[4. 로깅 드라이버](#4-로깅-드라이버)  
[5. rootless 모드 설치](#5-rootless-모드-설치)  
[6. rootless의 제약](#6-rootless의-제약)  
[7. 프록시 설정](#7-프록시-설정)  
[8. 실습](#8-실습)  
[9. 참고 링크](#9-참고-링크)

---

기본(rootful) 설치와, [Docker Engine 구조](/docker/overview-and-architecture/)에서 언급한 권한 문제를 근본적으로 피하는 rootless 설치를 함께 다룬다.



# 1. 설치 (dnf)
---

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

`docker-buildx-plugin`·`docker-compose-plugin`은 각각 `docker buildx`·`docker compose` 서브커맨드를 제공한다. 예전처럼 `docker-compose`를 별도 바이너리로 설치하지 않아도 된다.



# 2. rootful 기본 구성
---

```bash
sudo systemctl enable --now docker
docker run --rm hello-world
```

`sudo` 없이 쓰려면 `docker` 그룹에 사용자를 넣는다. 단, [Docker Engine 구조](/docker/overview-and-architecture/)에서 다뤘듯 이는 사실상 root 권한을 주는 것과 같다는 점을 감안한다.

```bash
sudo usermod -aG docker tempuser   # 그룹 반영은 재로그인 후
```



# 3. daemon.json 설정
---

`/etc/docker/daemon.json`(rootless는 `~/.config/docker/daemon.json`)에서 데몬 전역 설정을 관리한다.

```json
{
  "storage-driver": "overlay2",
  "data-root": "/mnt/docker-data",
  "log-driver": "journald",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

`storage-driver`는 대개 `overlay2`([overlay filesystem](/linux/storage-and-filesystem/) 참고)가 기본이고, `data-root`로 이미지·컨테이너·Volume이 실제로 쌓이는 위치(기본 `/var/lib/docker`)를 다른 디스크로 옮길 수 있다. 수정 후에는 재시작해야 반영된다.

```bash
sudo systemctl restart docker
docker info | grep -i 'storage driver'
```



# 4. 로깅 드라이버
---

| 드라이버 | 특징 |
| :-- | :-- |
| json-file (기본) | 컨테이너별 JSON 로그 파일. 로테이션 설정 안 하면 무한정 커질 수 있음 |
| local | json-file보다 오버헤드가 적고 기본적으로 로테이션 |
| journald | 호스트의 journald로 전달 |
| syslog | syslog 시설로 전달 |
| none | 로그를 아예 안 남김 |

`journald`로 설정하면 [로그와 저널](/linux/logging-and-journald/) 문서에서 다룬 `journalctl`로 컨테이너 로그까지 통합 조회할 수 있다.

```bash
docker run -d --log-driver journald --name tempweb nginx:alpine
journalctl CONTAINER_NAME=tempweb -f
```



# 5. rootless 모드 설치
---

[Docker Engine 구조](/docker/overview-and-architecture/)에서 다룬 `docker` 그룹의 권한 위험을 근본적으로 피하려면, 데몬 자체를 root가 아닌 사용자 권한으로 띄운다. [User Namespace와 rootless](/linux/namespace-and-cgroups/) 문서에서 다룬 `/etc/subuid`·`/etc/subgid`가 그대로 전제조건이다.

```bash
grep tempuser /etc/subuid /etc/subgid   # 65536개 이상의 subordinate UID·GID가 있어야 함
sudo dnf install -y docker-ce-rootless-extras
```

`sudo` 없이, 대상 사용자 본인으로 실행한다.

```bash
su - tempuser
dockerd-rootless-setuptool.sh install
```

데몬은 그 사용자의 systemd user 인스턴스로 뜬다 — [시스템 인스턴스와 user 인스턴스](/linux/process-and-systemd/)에서 다룬 그 구조다.

```bash
systemctl --user enable --now docker
loginctl enable-linger tempuser        # 로그아웃 후에도 데몬이 계속 떠 있게(lingering)

export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
docker run --rm hello-world
```

`enable-linger`를 켜지 않으면 tempuser의 로그인 세션이 모두 끝나는 순간 user 인스턴스가 함께 내려가면서 데몬도 죽는다.



# 6. rootless의 제약
---

**1024 미만 포트 바인딩 불가** — rootless 데몬은 진짜 root가 아니라 `CAP_NET_BIND_SERVICE`([Capabilities와 보안 모듈](/linux/capabilities-and-security-modules/) 참고)가 없다. 80·443 같은 포트를 직접 열려면 커널의 하한을 낮추거나,

```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```

호스트의 리버스 프록시(rootful nginx 등)로 앞단을 두는 방식을 택한다.

**cgroup delegation 필요** — `--memory`·`--cpus` 같은 리소스 제한은 [cgroup delegation](/linux/namespace-and-cgroups/)이 그 사용자에게 위임돼 있어야 동작한다. Fedora는 systemd가 로그인 사용자마다 기본으로 위임하므로 대개 별도 조치가 필요 없다.

**overlay 스토리지 드라이버** — 커널이 충분히 최신이면 rootless에서도 `overlay2`를 그대로 쓰지만, 지원하지 않는 환경에서는 `fuse-overlayfs`로 대체된다(성능이 다소 떨어짐).



# 7. 프록시 설정
---

사내망처럼 아웃바운드가 프록시를 거쳐야 하는 환경에서는 dockerd 자체의 systemd unit에 환경변수를 넣는다.

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf <<'EOF'
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:3128"
Environment="HTTPS_PROXY=http://proxy.example.com:3128"
Environment="NO_PROXY=localhost,127.0.0.1,.example.com"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```



# 8. 실습
---

```bash
sudo systemctl status docker
docker info | grep -iE 'storage driver|logging driver|cgroup'

# journald 로깅 드라이버로 컨테이너 실행 + 통합 로그 조회
docker run -d --log-driver journald --name tempweb nginx:alpine
journalctl CONTAINER_NAME=tempweb -n 5

docker rm -f tempweb
```



# 9. 참고 링크
---

─ Install Docker Engine — <https://docs.docker.com/engine/install/>  
─ Configure logging drivers — <https://docs.docker.com/engine/logging/configure/>  
─ Rootless mode — <https://docs.docker.com/engine/security/rootless/>
