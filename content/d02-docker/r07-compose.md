
---

***index***

[1. Compose란](#1-compose란)  
[2. compose.yaml 기본 구조](#2-composeyaml-기본-구조)  
[3. 서비스 정의](#3-서비스-정의)  
[4. 네트워크와 서비스 디스커버리](#4-네트워크와-서비스-디스커버리)  
[5. Volume 정의](#5-volume-정의)  
[6. 환경변수 관리](#6-환경변수-관리)  
[7. depends_on과 헬스체크](#7-depends_on과-헬스체크)  
[8. 프로파일](#8-프로파일)  
[9. 오버라이드 파일](#9-오버라이드-파일)  
[10. 실전 명령](#10-실전-명령)  
[11. 실습](#11-실습)  
[12. 참고 링크](#12-참고-링크)

---

여러 컨테이너로 구성된 애플리케이션을 YAML 파일 하나로 선언하고 `docker compose up` 한 줄로 띄우는 도구다. [네트워킹](/docker/networking/)에서 매번 `docker network create`·`--network`로 하던 걸, 서비스 관계만 선언하면 Compose가 알아서 사용자 정의 네트워크를 만들고 서비스 이름으로 DNS 해석까지 연결해준다.



# 1. Compose란
---

`docker-compose`라는 별도 바이너리 대신, 최신 Docker는 `docker compose` 서브커맨드(플러그인)로 통합 제공한다. [설치와 기본 환경 구성](/docker/installation-and-setup/)에서 설치한 `docker-compose-plugin`이 이것이다.



# 2. compose.yaml 기본 구조
---

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: temp
    volumes:
      - dbdata:/var/lib/postgresql/data

volumes:
  dbdata:
```

최상위 키는 `services`(컨테이너 각각의 정의), `volumes`(Volume 선언), `networks`(네트워크 선언, 생략하면 기본 네트워크가 자동 생성됨) 정도로 시작한다.



# 3. 서비스 정의
---

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    image: tempapp:1.0    # build 결과에 붙일 태그
```

```bash
docker compose build       # 이미지만 빌드
docker compose up --build   # 빌드 후 실행
```



# 4. 네트워크와 서비스 디스커버리
---

Compose는 프로젝트마다 기본 네트워크를 자동으로 만들고, 모든 서비스를 여기 연결한다 — [사용자 정의 bridge와 내장 DNS](/docker/networking/)에서 다룬 방식 그대로라 서비스 이름으로 바로 통신된다.

```yaml
services:
  web:
    image: nginx:alpine
    depends_on: [app]
  app:
    build: .
```

`web` 컨테이너 안에서 `http://app:3000`처럼 서비스 이름으로 바로 접근한다.



# 5. Volume 정의
---

[Volume과 데이터 영속성](/docker/volume-and-persistence/)에서 다룬 세 방식을 그대로 선언형으로 쓴다.

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - dbdata:/var/lib/postgresql/data      # named volume
      - ./config:/etc/postgresql:ro           # bind mount

volumes:
  dbdata:
```



# 6. 환경변수 관리
---

```yaml
services:
  app:
    image: tempapp:${APP_VERSION:-1.0}
    env_file: .env
```

```text
# .env
APP_VERSION=2.0
DB_PASSWORD=temp
```

`${APP_VERSION:-1.0}` 문법은 [셸 스크립팅과 자동화](/linux/shell-scripting-and-automation/)에서 다룬 bash 파라미터 확장과 같은 개념이다 — 값이 없으면 기본값을 쓴다.



# 7. depends_on과 헬스체크
---

```yaml
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
```

`depends_on`은 기본적으로 "먼저 시작만 하면" 통과하는 `service_started` 조건이다. DB 컨테이너 프로세스가 뜨는 것과 DB가 실제로 연결을 받을 준비가 되는 것은 다르므로, 순서를 제대로 보장하려면 `service_healthy`로 헬스체크와 연동한다(`service_completed_successfully`는 초기화 작업처럼 "끝까지 실행 완료"를 기다릴 때 쓴다).



# 8. 프로파일
---

```yaml
services:
  app:
    build: .
  debug-tools:
    image: busybox
    profiles: ["debug"]
```

```bash
docker compose up                    # debug-tools는 시작되지 않음
docker compose --profile debug up     # debug-tools까지 함께 시작
```



# 9. 오버라이드 파일
---

로컬 개발·운영 환경 차이는 별도 파일로 분리한다. `docker compose`는 기본적으로 `compose.yaml`과 `compose.override.yaml`을 자동으로 합쳐 읽는다.

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d
```



# 10. 실전 명령
---

```bash
docker compose up -d          # 백그라운드로 전체 기동
docker compose ps               # 서비스별 상태
docker compose logs -f app       # 특정 서비스 로그
docker compose exec app sh        # 특정 서비스 컨테이너에 진입
docker compose down               # 컨테이너·네트워크 정리(Volume은 기본 유지)
docker compose down -v            # Volume까지 삭제
```



# 11. 실습
---

`compose.yaml`:

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    depends_on:
      app:
        condition: service_healthy
  app:
    image: python:3.12-alpine
    command: ["python3", "-m", "http.server", "3000"]
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O- http://localhost:3000 || exit 1"]
      interval: 5s
      timeout: 3s
      retries: 5
```

```bash
docker compose up -d
docker compose ps
docker compose logs app

docker compose exec web wget -q -O- http://app:3000    # 서비스 이름으로 접근

docker compose down
```



# 12. 참고 링크
---

─ Compose file reference — <https://docs.docker.com/reference/compose-file/services/>  
─ Using profiles — <https://docs.docker.com/compose/how-tos/profiles/>
