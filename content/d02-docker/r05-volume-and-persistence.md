
---

***index***

[1. 세 가지 마운트 방식](#1-세-가지-마운트-방식)  
[2. Volume 관리 명령](#2-volume-관리-명령)  
[3. Volume이 저장되는 위치](#3-volume이-저장되는-위치)  
[4. Bind mount와 UID 매핑](#4-bind-mount와-uid-매핑)  
[5. SELinux 라벨](#5-selinux-라벨)  
[6. tmpfs mount](#6-tmpfs-mount)  
[7. 데이터 백업과 복원](#7-데이터-백업과-복원)  
[8. 실습](#8-실습)  
[9. 참고 링크](#9-참고-링크)

---

컨테이너 레이어는 컨테이너가 지워지면 함께 사라진다. 데이터를 남기려면 컨테이너 바깥에 저장해야 하고, 그 연결 방식이 Volume·Bind mount·tmpfs다.



# 1. 세 가지 마운트 방식
---

| 방식 | 관리 주체 | 특징 |
| :-- | :-- | :-- |
| Volume | Docker | `/var/lib/docker/volumes` 아래 Docker가 직접 관리. 백업·마이그레이션이 쉽고 여러 컨테이너 간 공유에 적합 |
| Bind mount | 사용자 | 호스트의 특정 경로를 그대로 노출. 호스트 파일시스템 구조에 의존 |
| tmpfs | 커널(메모리) | 디스크에 전혀 쓰이지 않음. 컨테이너 종료 시 사라짐 |



# 2. Volume 관리 명령
---

```bash
docker volume create tempvol
docker volume ls
docker volume inspect tempvol
docker run -d -v tempvol:/data --name tempweb nginx:alpine
docker volume rm tempvol
```



# 3. Volume이 저장되는 위치
---

```bash
docker volume inspect tempvol -f '{{.Mountpoint}}'
# /var/lib/docker/volumes/tempvol/_data
sudo ls /var/lib/docker/volumes/tempvol/_data
```

결국 호스트의 평범한 디렉터리다 — [스토리지와 파일시스템](/linux/storage-and-filesystem/)에서 다룬 파일시스템 위에 그대로 놓인다.



# 4. Bind mount와 UID 매핑
---

```bash
docker run -d -v /host/data:/data --name tempweb nginx:alpine
docker run -d --mount type=bind,source=/host/data,target=/data,readonly --name tempweb nginx:alpine
```

`-v`(짧은 문법)와 `--mount`(길지만 명시적)의 차이는, `--mount`가 오타로 인한 의도치 않은 디렉터리 자동 생성을 막고 옵션을 더 분명하게 드러낸다는 점이다.

Bind mount는 컨테이너 안 프로세스의 UID·GID가 그대로 호스트 파일 권한 검사에 쓰인다 — [기본 권한(rwx)](/linux/filesystem-and-permissions/)에서 다룬 커널의 UID 매치 판정이 컨테이너 경계를 넘어 그대로 적용된다는 뜻이다. 컨테이너가 UID 1000으로 돌고 호스트 디렉터리가 다른 사용자 소유라면 권한 거부가 난다.

```bash
docker run --rm -v /host/data:/data alpine id                                    # 컨테이너 안 UID 확인
docker run --rm --user "$(id -u):$(id -g)" -v /host/data:/data alpine touch /data/test   # 호스트 UID로 맞춰 실행
```



# 5. SELinux 라벨
---

SELinux가 Enforcing인 호스트([SELinux 모드](/linux/capabilities-and-security-modules/) 참고)에서는 컨테이너 프로세스(`container_t`)가 일반 호스트 디렉터리에 접근하는 것 자체가 정책 위반으로 거부될 수 있다. Bind mount에 `:z`·`:Z` 옵션을 붙이면 Docker가 마운트 시점에 그 경로를 컨테이너가 접근 가능한 컨텍스트로 자동 relabel한다.

```bash
docker run -d -v /host/data:/data:z --name tempweb nginx:alpine     # 여러 컨테이너가 공유 가능하게
docker run -d -v /host/data:/data:Z --name tempweb nginx:alpine     # 이 컨테이너 전용(비공유)으로
```

`:z`는 [MCS와 컨테이너 격리](/linux/capabilities-and-security-modules/)에서 다룬 공유 가능한 카테고리로, `:Z`는 이 컨테이너만의 고유 카테고리로 라벨을 바꾼다.

```bash
ls -Z /host/data    # 마운트 후 실제로 컨텍스트가 바뀐 것을 확인
```

`/`나 `/home`처럼 넓은 시스템 경로에 `:Z`를 걸면 그 경로 전체의 라벨이 이 컨테이너 전용으로 바뀌어 다른 프로세스가 접근하지 못하게 되는 사고로 이어질 수 있다 — 반드시 컨테이너 전용으로 만든 좁은 디렉터리에만 건다.



# 6. tmpfs mount
---

```bash
docker run -d --tmpfs /tmp:size=100m,mode=1777 --name tempweb nginx:alpine
```

디스크에 전혀 쓰이지 않고 메모리에만 존재한다 — 컨테이너가 죽으면 그 데이터도 함께 사라진다. 비밀값을 잠깐 담아두는 용도나, 성능이 중요한 캐시 디렉터리에 쓴다.



# 7. 데이터 백업과 복원
---

Volume은 호스트 경로를 직접 몰라도 임시 컨테이너를 하나 띄워 백업할 수 있다.

```bash
docker run --rm -v tempvol:/data -v "$(pwd)":/backup alpine \
  tar czf /backup/tempvol-backup.tar.gz -C /data .

docker volume create tempvol-restored
docker run --rm -v tempvol-restored:/data -v "$(pwd)":/backup alpine \
  tar xzf /backup/tempvol-backup.tar.gz -C /data
```



# 8. 실습
---

```bash
docker volume create tempvol
docker run -d -v tempvol:/data --name tempwrite alpine sh -c 'date > /data/stamp; sleep 3600'
docker exec tempwrite cat /data/stamp

docker rm -f tempwrite
docker run --rm -v tempvol:/data alpine cat /data/stamp    # 컨테이너가 바뀌어도 데이터 유지 확인

mkdir -p /tmp/bindtest
echo "host file" > /tmp/bindtest/hello.txt
docker run --rm -v /tmp/bindtest:/data:z alpine cat /data/hello.txt
ls -Z /tmp/bindtest

docker volume rm tempvol
```



# 9. 참고 링크
---

─ Volumes — <https://docs.docker.com/engine/storage/volumes/>  
─ Bind mounts — <https://docs.docker.com/engine/storage/bind-mounts/>
