
---

***index***

[1. 이미지 레이어 구조](#1-이미지-레이어-구조)  
[2. Dockerfile 기본 명령어](#2-dockerfile-기본-명령어)  
[3. ENTRYPOINT와 CMD](#3-entrypoint와-cmd)  
[4. ARG와 ENV](#4-arg와-env)  
[5. 빌드 캐시와 레이어 순서](#5-빌드-캐시와-레이어-순서)  
[6. 멀티스테이지 빌드](#6-멀티스테이지-빌드)  
[7. dockerignore](#7-dockerignore)  
[8. BuildKit과 buildx](#8-buildkit과-buildx)  
[9. 이미지 크기 최적화](#9-이미지-크기-최적화)  
[10. 이미지 검사](#10-이미지-검사)  
[11. 실습](#11-실습)  
[12. 참고 링크](#12-참고-링크)

---

이미지는 여러 읽기 전용 레이어를 쌓은 것이다. [overlay filesystem](/linux/storage-and-filesystem/)에서 다룬 lowerdir 여러 겹이 실제로 이 레이어들이고, Dockerfile은 그 레이어를 어떤 순서로 어떻게 쌓을지 적는 설계도다.



# 1. 이미지 레이어 구조
---

Dockerfile에서 파일시스템을 바꾸는 명령(`RUN`·`COPY`·`ADD` 등)이 하나씩 레이어를 만든다. 컨테이너를 실행하면 이 읽기 전용 레이어들 위에 쓰기 가능한 얇은 레이어(컨테이너 레이어) 하나가 더 얹힌다.

```bash
docker history nginx:alpine                                     # 레이어별 크기·생성 명령
docker inspect nginx:alpine -f '{{.RootFS.Layers}}' | tr ' ' '\n'
```



# 2. Dockerfile 기본 명령어
---

```dockerfile
FROM alpine:3.20
WORKDIR /app
COPY app.py .
RUN pip install flask
EXPOSE 5000
USER nobody
ENTRYPOINT ["python3", "app.py"]
```

| 명령 | 역할 |
| :-- | :-- |
| `FROM` | 베이스 이미지 지정 |
| `RUN` | 이미지 빌드 중 명령 실행(레이어 생성) |
| `COPY` | 빌드 컨텍스트의 파일을 이미지로 복사 |
| `ADD` | COPY + URL 다운로드·tar 자동 압축해제 등 부가 기능. 동작이 예측하기 어려워 특별한 이유가 없으면 `COPY`를 쓴다 |
| `WORKDIR` | 이후 명령의 작업 디렉터리 |
| `EXPOSE` | 이 컨테이너가 쓰는 포트를 문서화(실제로 포트를 열지는 않음, `-p`가 따로 필요) |
| `USER` | 이후 명령·컨테이너 실행 시의 사용자 |
| `VOLUME` | 이 경로를 익명 Volume으로 만들도록 표시 |



# 3. ENTRYPOINT와 CMD
---

`CMD`는 컨테이너 실행 시 기본으로 실행할 명령이고, `ENTRYPOINT`는 컨테이너를 하나의 실행 프로그램처럼 만든다. `docker run image 인자`의 `인자`는 `CMD`를 통째로 덮어쓰지만, `ENTRYPOINT`가 있으면 그 인자로 붙는다.

```dockerfile
ENTRYPOINT ["top", "-b"]
CMD ["-c"]
```

```bash
docker run tempimg            # top -b -c 실행
docker run tempimg -d 5        # top -b -d 5 실행 (CMD가 -d 5로 교체됨)
```

**exec form**(`["cmd", "arg"]`)은 프로세스를 직접 실행해 신호(`SIGTERM` 등)가 그대로 전달된다. **shell form**(`cmd arg`)은 내부적으로 `/bin/sh -c`를 거치므로 환경변수 치환은 되지만, 신호가 `sh`가 아니라 그 자식 프로세스까지 제대로 전달되지 않을 수 있다. `docker stop`이 안 먹고 매번 유예시간을 다 채우고 강제 종료된다면 이 shell form 문제를 의심한다.



# 4. ARG와 ENV
---

| 구분 | ARG | ENV |
| :-- | :-- | :-- |
| 유효 범위 | 빌드 시점만 | 빌드 + 런타임(컨테이너 실행 중까지) |
| 최종 이미지 포함 | 안 됨 | 됨 |
| 지정 방법 | `docker build --build-arg` | Dockerfile에서 영구 설정 |

```dockerfile
ARG VERSION=1.0
ENV APP_VERSION=${VERSION}
```

```bash
docker build --build-arg VERSION=2.0 -t tempapp .
```

빌드 시점에만 필요한 값(다운로드 URL 버전 등)은 `ARG`, 런타임에 애플리케이션이 읽어야 하는 값은 `ENV`를 쓴다. 같은 이름을 쓰면 `ENV`가 `ARG`를 덮어쓴다.



# 5. 빌드 캐시와 레이어 순서
---

자주 안 바뀌는 명령을 앞에, 자주 바뀌는 명령을 뒤에 둬야 캐시 재사용률이 높다.

```dockerfile
# 나쁜 예: 소스 코드가 한 글자만 바뀌어도 npm install이 매번 다시 돔
COPY . .
RUN npm install

# 좋은 예: package.json이 그대로면 npm install 레이어가 캐시에서 재사용됨
COPY package.json package-lock.json ./
RUN npm install
COPY . .
```

캐시는 명령 문자열과 `COPY`로 들어오는 파일의 체크섬을 기준으로 판단한다(BuildKit은 이 추적을 더 정밀하게 한다).



# 6. 멀티스테이지 빌드
---

빌드에만 필요한 도구(컴파일러 등)를 최종 이미지에서 빼기 위해 `FROM`을 여러 번 두고, 마지막 단계만 결과 이미지로 삼는다.

```dockerfile
FROM golang:1.22 AS builder
WORKDIR /src
COPY . .
RUN go build -o /out/app .

FROM alpine:3.20
COPY --from=builder /out/app /usr/local/bin/app
ENTRYPOINT ["/usr/local/bin/app"]
```

최종 이미지에는 Go 컴파일러가 전혀 남지 않아 공격 표면과 크기가 크게 준다.



# 7. dockerignore
---

`COPY . .`는 빌드 컨텍스트 전체를 dockerd로 보낸 뒤 그 안에서 복사한다. `.dockerignore`로 불필요하거나 민감한 파일을 미리 걸러낸다.

```text
.git
node_modules
*.log
.env
```

`.env`나 사설 키처럼 이미지에 절대 들어가면 안 되는 파일은 반드시 여기 넣는다 — 이미지 레이어는 한 번 만들어지면 `docker history`로 계속 들여다볼 수 있어서, 나중에 지워도 이전 레이어에 그대로 남는다.



# 8. BuildKit과 buildx
---

BuildKit은 최신 빌드 엔진이다. 서로 독립적인 스테이지를 병렬로 빌드하고, 필요 없는 스테이지는 아예 건너뛰며, 캐시를 체크섬 기반으로 정밀하게 추적한다(레거시 빌더의 휴리스틱 비교보다 정확). 최신 Docker는 기본으로 BuildKit을 쓴다.

```bash
docker buildx build -t tempapp:1.0 .
docker buildx build --platform linux/amd64,linux/arm64 -t tempapp:1.0 .   # 멀티 아키텍처 빌드
```

캐시 마운트를 쓰면 반복 빌드할 때 패키지 매니저 캐시를 레이어에 굽지 않고 재사용할 수 있다.

```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
```



# 9. 이미지 크기 최적화
---

베이스 이미지를 가볍게 고르고(`alpine`, distroless 계열), 멀티스테이지로 빌드 도구를 빼고, 같은 레이어 안에서 설치와 정리를 함께 해야 한다.

```dockerfile
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
```

설치를 한 `RUN`, 정리를 다른 `RUN`으로 나누면 정리 효과가 레이어 크기에 반영되지 않는다 — 이전 레이어에 이미 구워진 파일은 그대로 이미지 용량을 차지한 채 남기 때문이다.



# 10. 이미지 검사
---

```bash
docker history --no-trunc tempapp:1.0   # 레이어별 생성 명령 전체
docker inspect tempapp:1.0
```

레이어별로 어떤 파일이 실제로 추가·삭제됐는지 더 깊이 보려면 `dive` 같은 서드파티 도구를 쓴다. 이미지 취약점 스캔은 [리소스 제한과 보안](/docker/resource-and-security/)에서 다룬다.



# 11. 실습
---

`Dockerfile`:

```dockerfile
FROM golang:1.22 AS builder
WORKDIR /src
RUN printf 'package main\nimport "fmt"\nfunc main() { fmt.Println("hello from tempapp") }' > main.go
RUN go build -o /out/tempapp main.go

FROM alpine:3.20
COPY --from=builder /out/tempapp /usr/local/bin/tempapp
ENTRYPOINT ["/usr/local/bin/tempapp"]
```

```bash
docker buildx build -t tempapp:1.0 .
docker history tempapp:1.0
docker images tempapp:1.0     # golang 빌드 이미지가 아니라 alpine 기반 크기만 남는 것 확인

docker run --rm tempapp:1.0
```



# 12. 참고 링크
---

─ Dockerfile reference — <https://docs.docker.com/reference/dockerfile/>  
─ BuildKit — <https://docs.docker.com/build/buildkit/>
