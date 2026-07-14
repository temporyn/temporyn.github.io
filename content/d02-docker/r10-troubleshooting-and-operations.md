
---

***index***

[1. 로그 확인](#1-로그-확인)  
[2. 컨테이너 내부 디버깅](#2-컨테이너-내부-디버깅)  
[3. 리소스 모니터링](#3-리소스-모니터링)  
[4. 일반적인 문제 패턴](#4-일반적인-문제-패턴)  
[5. 데몬 자체 디버깅](#5-데몬-자체-디버깅)  
[6. 정리와 디스크 관리](#6-정리와-디스크-관리)  
[7. 헬스체크](#7-헬스체크)  
[8. 실습](#8-실습)  
[9. 참고 링크](#9-참고-링크)

---

컨테이너 트러블슈팅의 상당 부분은 결국 [Linux](/linux/) 시리즈에서 배운 프로세스·cgroup·네트워크 디버깅 도구를 컨테이너라는 대상에 그대로 적용하는 일이다.



# 1. 로그 확인
---

```bash
docker logs tempweb
docker logs --since 10m --tail 200 tempweb
docker logs -t tempweb    # 타임스탬프 포함
```

로깅 드라이버가 `journald`([설치와 기본 환경 구성](/docker/installation-and-setup/) 참고)면 [로그와 저널](/linux/logging-and-journald/)에서 배운 필터링을 그대로 쓸 수 있다.

```bash
journalctl CONTAINER_NAME=tempweb -p err
```



# 2. 컨테이너 내부 디버깅
---

`docker exec`가 안 먹는 상황(이미지에 셸이 없는 distroless 등)에서는 호스트 관점에서 직접 들어간다.

```bash
PID=$(docker inspect -f '{{.State.Pid}}' tempweb)
sudo nsenter -t "$PID" -n ss -tlnp     # 네트워크 namespace만 빌려 포트 확인
sudo nsenter -t "$PID" -a bash          # 전체 namespace를 빌려 완전히 들어가기(호스트에 bash 필요)
```

[Namespace 확인](/linux/namespace-and-cgroups/)에서 다룬 `nsenter`가 그대로 통한다 — 컨테이너는 결국 특정 Namespace 조합을 가진 평범한 프로세스이기 때문이다. Docker는 이 패턴을 감싼, 대상 컨테이너와 Namespace를 공유하는 임시 디버그 컨테이너를 붙이는 방식도 제공한다.

```bash
docker run -it --rm --pid=container:tempweb --network=container:tempweb busybox sh
```



# 3. 리소스 모니터링
---

```bash
docker stats
docker stats --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
```

여러 호스트에 걸친 모니터링은 이 시리즈 이후 다룰 Kubernetes 쪽 도구(cAdvisor, Prometheus)로 넘어가는 영역이다.



# 4. 일반적인 문제 패턴
---

| 증상 | 원인 | 확인 |
| :-- | :-- | :-- |
| `OOMKilled` | 메모리 상한 초과 | `docker inspect -f '{{.State.OOMKilled}}'` |
| pull access denied | 인증 누락·태그 오타 | `docker login`, 태그 재확인 |
| 계속 재시작(`Restarting`) | 애플리케이션이 시작 직후 크래시 | `docker logs --tail 50` |
| 포트 연결 안 됨 | `-p` 누락, 방화벽, 바인딩 주소(`0.0.0.0` vs `127.0.0.1`) | `docker port`, `ss -tlnp` |
| `Exited (137)` | SIGKILL로 종료(OOM 또는 강제 종료) | `dmesg \| grep -i oom` |
| `Exited (143)` | SIGTERM으로 정상 종료 | — |

종료 코드로 원인을 짐작하는 관행이 있다: 128 + 신호 번호([시그널](/linux/process-and-systemd/) 참고)다. 137은 128+9(SIGKILL), 143은 128+15(SIGTERM)이다.

```bash
docker inspect -f '{{.State.ExitCode}}' tempweb
docker inspect -f '{{.State.OOMKilled}}' tempweb
```



# 5. 데몬 자체 디버깅
---

dockerd도 결국 systemd unit([systemctl](/linux/process-and-systemd/) 참고)이라 같은 방식으로 다룬다.

```bash
systemctl status docker
journalctl -u docker -f
```



# 6. 정리와 디스크 관리
---

```bash
docker system df -v                                        # 이미지·컨테이너·Volume별 상세 사용량
docker system prune -a --volumes --filter "until=240h"       # 10일 넘은 것만 정리
```

`data-root`([daemon.json 설정](/docker/installation-and-setup/) 참고)가 있는 디스크 자체의 여유 공간은 [스토리지와 파일시스템](/linux/storage-and-filesystem/)에서 배운 `df -h`·`iostat`로 별도로 감시한다.



# 7. 헬스체크
---

Dockerfile에 `HEALTHCHECK`를 지정하면 `docker ps`의 STATUS에 `(healthy)`/`(unhealthy)`가 표시된다.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q -O- http://localhost/ || exit 1
```

```bash
docker inspect -f '{{.State.Health.Status}}' tempweb
docker inspect -f '{{json .State.Health.Log}}' tempweb
```

[Compose](/docker/compose/)의 `depends_on: condition: service_healthy`가 참조하는 상태가 바로 이것이다.



# 8. 실습
---

```bash
docker run -d --name tempweb \
  --health-cmd='wget -q -O- http://localhost/ || exit 1' \
  --health-interval=5s --health-retries=3 \
  -p 8080:80 nginx:alpine

sleep 6
docker inspect -f '{{.State.Health.Status}}' tempweb

PID=$(docker inspect -f '{{.State.Pid}}' tempweb)
sudo nsenter -t "$PID" -n ss -tlnp

# 메모리를 일부러 낮게 잡아 OOMKilled 재현
docker update --memory=20m --memory-swap=20m tempweb || true
docker exec tempweb sh -c 'cat /dev/zero | head -c 100m > /dev/null' || true
docker inspect -f '{{.State.OOMKilled}}' tempweb

docker rm -f tempweb
docker system df
```



# 9. 참고 링크
---

─ docker logs — <https://docs.docker.com/reference/cli/docker/container/logs/>  
─ HEALTHCHECK — <https://docs.docker.com/reference/dockerfile/#healthcheck>
