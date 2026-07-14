
---

***index***

[1. 리소스 제한](#1-리소스-제한)  
[2. capabilities 제어](#2-capabilities-제어)  
[3. seccomp 프로파일](#3-seccomp-프로파일)  
[4. SELinux 옵션](#4-selinux-옵션)  
[5. no-new-privileges와 read-only 파일시스템](#5-no-new-privileges와-read-only-파일시스템)  
[6. rootless와 userns-remap](#6-rootless와-userns-remap)  
[7. 이미지 취약점 스캔](#7-이미지-취약점-스캔)  
[8. 실습](#8-실습)  
[9. 참고 링크](#9-참고-링크)

---

[커널 Namespace와 cgroups](/linux/namespace-and-cgroups/)에서 정리한 컨테이너의 네 축 — Namespace·cgroups·Capabilities·seccomp — 을 Docker가 실제로 어떤 옵션으로 조정하게 해주는지 다룬다. 여기 나오는 옵션 대부분은 새 개념이 아니라 이미 Linux 문서 시리즈에서 배운 커널 기능의 손잡이다.



# 1. 리소스 제한
---

```bash
docker run -d --memory=512m --memory-swap=512m --cpus=1.5 --name tempapp myapp:1.0
```

`--memory-swap`을 `--memory`와 같은 값으로 주면 스왑 사용 자체를 차단한다(값을 생략하면 컨테이너는 `--memory`만큼 스왑을 추가로 더 쓸 수 있고, `-1`이면 호스트 스왑 전체를 허용). 이 옵션들은 결국 [cgroup v2 구조](/linux/namespace-and-cgroups/)에서 다룬 `memory.max`·`cpu.max`를 dockerd가 대신 써주는 것이다.

```bash
docker inspect -f '{{.Id}}' tempapp
cat /sys/fs/cgroup/system.slice/docker-*.scope/memory.max
```

메모리 상한을 넘기면 커널 OOM killer가 컨테이너 프로세스를 죽인다 — `docker ps -a`의 STATUS에 `OOMKilled`로 나타난다. 결국 [좀비와 고아 프로세스](/linux/process-and-systemd/) 등과 마찬가지로 커널이 처리하는 일반 프로세스 종료 이벤트일 뿐이다.



# 2. capabilities 제어
---

[capability 조회와 부여](/linux/capabilities-and-security-modules/)에서 다룬 개념 그대로, 컨테이너는 기본적으로 root로 떠도 전체 root 권한이 아니라 정해진 부분집합만 가진다. `--cap-drop=ALL`로 전부 지우고 필요한 것만 다시 더하는 게 권장 패턴이다.

```bash
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE -d -p 80:80 --name tempweb nginx:alpine
docker run --rm --cap-drop=ALL alpine sh -c 'mount' 2>&1     # CAP_SYS_ADMIN이 없어 실패
```

컨테이너 안에서 실제로 어떤 capability를 들고 있는지는 [capsh로 실험하기](/linux/capabilities-and-security-modules/)에서 다룬 방식 그대로 확인할 수 있다.

```bash
docker exec tempweb cat /proc/1/status | grep Cap
```



# 3. seccomp 프로파일
---

Docker는 기본으로 300개가 넘는 syscall 중 약 44개를 막는 프로파일을 적용한다([seccomp: 세 번째 축](/linux/namespace-and-cgroups/) 참고) — `mount`·`reboot`·`ptrace`·`unshare`·커널 모듈 조작처럼 컨테이너 안에서 굳이 필요 없는 위험한 호출들이다.

```bash
docker run --rm alpine grep Seccomp /proc/1/status                                  # 2 = filter 모드로 동작 중
docker run --rm --security-opt seccomp=unconfined alpine grep Seccomp /proc/1/status   # 0 = 비활성화(위험)
```

특정 앱이 기본 프로파일에서 막힌 syscall을 정말 필요로 한다면, 그 syscall만 추가로 허용한 커스텀 프로파일을 적용한다.

```bash
docker run --security-opt seccomp=./custom-seccomp.json myapp:1.0
```



# 4. SELinux 옵션
---

[MCS와 컨테이너 격리](/linux/capabilities-and-security-modules/)에서 다룬 라벨링을 `--security-opt label=`로 직접 조정할 수 있다.

```bash
docker run --security-opt label=type:my_container_t myapp:1.0     # 커스텀 SELinux 타입 적용
docker run --security-opt label=disable myapp:1.0                    # SELinux 격리 끔(디버깅용, 운영 비권장)
```

[Volume과 데이터 영속성](/docker/volume-and-persistence/)에서 다룬 `:z`/`:Z` Bind mount 라벨도 이 MCS 메커니즘의 일부다.



# 5. no-new-privileges와 read-only 파일시스템
---

```bash
docker run --security-opt no-new-privileges -d myapp:1.0
docker run --read-only --tmpfs /tmp -d myapp:1.0
```

`no-new-privileges`는 컨테이너 안에서 setuid 바이너리를 실행해도 그걸로 새 권한을 얻지 못하게 막는다 — [특수 권한 비트](/linux/filesystem-and-permissions/)에서 다룬 setuid 권한 상승 자체를 원천 차단하는 것이다. `--read-only`는 루트 파일시스템 전체를 읽기 전용으로 만들어, 침해당해도 컨테이너 이미지 자체는 변조되지 못하게 한다 — 쓰기가 필요한 경로만 `--tmpfs`나 Volume으로 따로 열어준다.



# 6. rootless와 userns-remap
---

[설치와 기본 환경 구성](/docker/installation-and-setup/)에서 다룬 rootless 모드는 데몬 자체를 비특권 사용자로 띄우는 방식이었다. 데몬은 root로 그대로 두면서 **컨테이너 안의 UID 매핑만** 격리하고 싶다면 `--userns-remap`을 쓴다.

```json
// /etc/docker/daemon.json
{ "userns-remap": "default" }
```

컨테이너 안 UID 0이 호스트에서는 특권 없는 임의 UID(예: 231072)로 매핑된다 — [User Namespace와 rootless](/linux/namespace-and-cgroups/)에서 다룬 `subuid` 메커니즘을 데몬이 대신 처리해주는 것이다. 다만 dockerd 자체는 여전히 root로 돈다는 게 rootless 모드와의 결정적 차이다. `userns-remap`은 컨테이너 격리를 강화하고, rootless 모드는 데몬 자체의 권한을 없앤다 — 서로 다른 층위를 보호하는 별개의 방어선이다.



# 7. 이미지 취약점 스캔
---

```bash
docker scout cves tempapp:1.0     # Docker 내장 스캐너
```

서드파티로는 `trivy`가 널리 쓰인다.

```bash
trivy image tempapp:1.0
```

CI 파이프라인에서 "심각도 HIGH 이상 발견 시 빌드 실패" 같은 게이트를 걸어, 취약한 베이스 이미지가 그대로 배포되는 걸 미리 막는다.



# 8. 실습
---

```bash
docker run -d --name tempweb \
  --memory=256m --memory-swap=256m --cpus=0.5 \
  --cap-drop=ALL --cap-add=NET_BIND_SERVICE \
  --security-opt no-new-privileges \
  --read-only --tmpfs /var/cache/nginx --tmpfs /var/run \
  -p 8080:80 \
  nginx:alpine

docker ps
docker exec tempweb cat /proc/1/status | grep -E 'Cap|Seccomp'
docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' tempweb

docker rm -f tempweb
```



# 9. 참고 링크
---

─ Resource constraints — <https://docs.docker.com/engine/containers/resource_constraints/>  
─ Seccomp security profiles — <https://docs.docker.com/engine/security/seccomp/>  
─ Isolate containers with a user namespace — <https://docs.docker.com/engine/security/userns-remap/>
