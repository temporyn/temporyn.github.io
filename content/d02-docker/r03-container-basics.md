
---

***index***

[1. run의 내부 동작](#1-run의-내부-동작)  
[2. 주요 옵션](#2-주요-옵션)  
[3. 재시작 정책](#3-재시작-정책)  
[4. 라이프사이클 명령](#4-라이프사이클-명령)  
[5. exec와 attach](#5-exec와-attach)  
[6. 로그와 inspect](#6-로그와-inspect)  
[7. cp로 파일 주고받기](#7-cp로-파일-주고받기)  
[8. stats로 리소스 확인](#8-stats로-리소스-확인)  
[9. 정리 명령](#9-정리-명령)  
[10. 실습](#10-실습)  
[11. 참고 링크](#11-참고-링크)

---

컨테이너를 다루는 명령 대부분은 결국 호스트의 평범한 프로세스([프로세스와 systemd](/linux/process-and-systemd/) 참고)를 다루는 것과 같은 얘기다 — 그 사실이 드러나는 지점들을 함께 짚는다.



# 1. run의 내부 동작
---

`docker run`은 사실 세 단계의 합성이다. 로컬에 이미지가 없으면 pull, 컨테이너 생성(create), 시작(start).

```bash
docker pull nginx:alpine
docker create --name tempweb nginx:alpine
docker start tempweb
# 위 세 줄이 docker run -d --name tempweb nginx:alpine 과 동일한 결과
```



# 2. 주요 옵션
---

```bash
docker run -d --name tempweb -p 8080:80 nginx:alpine
docker run -it --rm alpine sh
docker run -e APP_ENV=production --name tempapp myapp:1.0
```

| 옵션 | 의미 |
| :-- | :-- |
| `-d` | 백그라운드(detached) 실행 |
| `-it` | 인터랙티브 + 가상 터미널 할당 |
| `--rm` | 컨테이너 종료 시 자동 삭제 |
| `--name` | 컨테이너 이름 지정(생략 시 임의 이름) |
| `-e` | 환경변수 지정 |
| `-p host:container` | 포트 게시 |
| `-v` | Volume·Bind mount 연결 |



# 3. 재시작 정책
---

`--restart`로 컨테이너가 종료됐을 때 자동 재시작 여부를 정한다.

| 정책 | 동작 |
| :-- | :-- |
| no (기본) | 자동 재시작 안 함 |
| on-failure[:N] | 오류(0 아닌 종료 코드)로 끝났을 때만 재시작. N번까지 제한 가능. 데몬 자체가 재시작될 때는 적용 안 됨 |
| always | 항상 재시작. 데몬이 재시작되거나 사용자가 수동으로 다시 시작한 경우에만 재개 |
| unless-stopped | always와 비슷하지만, 사용자가 수동으로 정지시킨 컨테이너는 데몬이 재시작돼도 다시 살아나지 않음 |

```bash
docker run -d --restart unless-stopped --name tempweb nginx:alpine
docker update --restart on-failure:5 tempweb    # 실행 중에도 정책 변경 가능
```



# 4. 라이프사이클 명령
---

```bash
docker stop tempweb      # SIGTERM 전송 → 유예시간(기본 10초) 후 SIGKILL
docker kill tempweb      # 즉시 SIGKILL
docker start tempweb
docker restart tempweb
docker pause tempweb     # 프로세스 전체를 신호 없이 일시 정지
docker unpause tempweb
docker rm tempweb        # 정지된 컨테이너 삭제. 실행 중이면 -f 필요
```

`docker stop`의 SIGTERM → 유예 → SIGKILL 흐름은 [프로세스와 systemd](/linux/process-and-systemd/)에서 본 systemd unit 종료 순서와 개념이 같다. `docker pause`는 [커널 Namespace와 cgroups](/linux/namespace-and-cgroups/)에서 다룬 cgroup의 freezer 기능을 그대로 쓴다 — 신호를 보내는 게 아니라 커널이 그 cgroup에 속한 프로세스 전체의 스케줄링 자체를 멈춘다.



# 5. exec와 attach
---

`exec`는 이미 도는 컨테이너 안에 **새 프로세스**를 추가로 띄운다(디버깅용 셸 진입 등). `attach`는 새 프로세스를 만들지 않고 컨테이너의 **메인 프로세스(PID 1)**의 표준입출력에 그대로 접속한다.

```bash
docker exec -it tempweb sh    # 새 셸 프로세스를 컨테이너 안에 추가
docker attach tempweb         # 메인 프로세스의 stdin/stdout에 직접 연결
```

`attach` 상태에서 `Ctrl+C`는 컨테이너 메인 프로세스에 신호를 보내 죽일 수 있다 — 안전하게 분리하려면 `Ctrl+P Ctrl+Q`를 쓴다.



# 6. 로그와 inspect
---

```bash
docker logs tempweb
docker logs -f --tail 100 tempweb
docker inspect tempweb                       # 전체 메타데이터(JSON)
docker inspect -f '{{.State.Pid}}' tempweb    # Go 템플릿으로 특정 필드만
docker inspect -f '{{.NetworkSettings.IPAddress}}' tempweb
```

`State.Pid`는 호스트 관점의 실제 PID다. 컨테이너는 결국 호스트에서 보이는 평범한 프로세스이므로, [프로세스와 systemd](/linux/process-and-systemd/)·[Namespace와 cgroups](/linux/namespace-and-cgroups/)에서 배운 도구로 직접 들여다볼 수 있다.

```bash
sudo nsenter -t "$(docker inspect -f '{{.State.Pid}}' tempweb)" -n ss -tlnp
```



# 7. cp로 파일 주고받기
---

```bash
docker cp tempweb:/etc/nginx/nginx.conf ./nginx.conf  # 컨테이너 -> 호스트
docker cp ./nginx.conf tempweb:/etc/nginx/nginx.conf  # 호스트 -> 컨테이너
```



# 8. stats로 리소스 확인
---

```bash
docker stats                        # 전체 컨테이너 실시간 CPU·메모리·네트워크·블록 I/O
docker stats --no-stream tempweb    # 한 번만 찍고 종료
```

이 수치는 실제로 [cgroup v2 구조](/linux/namespace-and-cgroups/)에서 다룬 `memory.current`·`cpu.stat` 같은 파일을 읽어 계산한 값이다.

```bash
docker inspect -f '{{.Id}}' tempweb
cat /sys/fs/cgroup/system.slice/docker-*.scope/memory.current 2>/dev/null | head -1
```



# 9. 정리 명령
---

```bash
docker container prune              # 정지된 컨테이너 전부 삭제
docker image prune                   # 어느 컨테이너도 참조하지 않는 이미지(dangling) 삭제
docker volume prune                   # 어느 컨테이너도 쓰지 않는 Volume 삭제
docker system prune -a --volumes      # 위 전부 + 사용하지 않는 이미지까지 강하게 정리
docker system df                       # 이미지·컨테이너·Volume이 차지하는 용량 요약
```



# 10. 실습
---

```bash
docker run -d --name tempweb --restart unless-stopped -p 8080:80 nginx:alpine
docker ps
docker logs tempweb

docker exec -it tempweb sh -c 'hostname; ps aux'
docker inspect -f '{{.State.Pid}}' tempweb

docker pause tempweb
docker ps -a                          # STATUS가 Paused로 표시
docker unpause tempweb

docker cp tempweb:/etc/os-release ./tempweb-os-release
cat tempweb-os-release

docker stats --no-stream tempweb
docker rm -f tempweb
docker system df
```



# 11. 참고 링크
---

─ docker run reference — <https://docs.docker.com/reference/cli/docker/container/run/>  
─ Start containers automatically — <https://docs.docker.com/engine/containers/start-containers-automatically/>
