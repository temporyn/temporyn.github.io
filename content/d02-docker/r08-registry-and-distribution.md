
---

***index***

[1. 레지스트리 개념](#1-레지스트리-개념)  
[2. 태깅과 push·pull](#2-태깅과-pushpull)  
[3. 사설 레지스트리 구축](#3-사설-레지스트리-구축)  
[4. 인증과 credential helper](#4-인증과-credential-helper)  
[5. 이미지 서명과 검증](#5-이미지-서명과-검증)  
[6. CI/CD 파이프라인 연결](#6-cicd-파이프라인-연결)  
[7. 실습](#7-실습)  
[8. 참고 링크](#8-참고-링크)

---

빌드한 이미지를 다른 서버·클러스터에서 쓰려면 레지스트리에 올려야 한다. [OCI 표준](/docker/overview-and-architecture/)에서 다룬 Distribution Spec이 이 push/pull API의 표준이다.



# 1. 레지스트리 개념
---

Docker Hub 같은 공개 레지스트리를 쓸 수도, 사내에 사설 레지스트리를 둘 수도 있다. 이미지 이름 앞에 붙는 호스트명이 곧 "어느 레지스트리를 쓸지"를 정한다 — 생략하면 Docker Hub가 기본이다.



# 2. 태깅과 push·pull
---

```bash
docker tag tempapp:1.0 registry.example.com/myteam/tempapp:1.0
docker push registry.example.com/myteam/tempapp:1.0
docker pull registry.example.com/myteam/tempapp:1.0
```

digest(불변 식별자)로 정확한 버전을 고정할 수도 있다.

```bash
docker pull nginx@sha256:abcdef...    # 태그가 나중에 다른 이미지를 가리키게 바뀌어도 이 내용은 절대 안 바뀜
```



# 3. 사설 레지스트리 구축
---

```bash
docker run -d -p 5000:5000 --name registry registry:3
docker tag tempapp:1.0 localhost:5000/tempapp:1.0
docker push localhost:5000/tempapp:1.0
docker pull localhost:5000/tempapp:1.0
```

Docker Registry는 2019년 CNCF에 기증돼 지금은 **Distribution** 프로젝트로 이어지고 있다. HTTPS 없이 사설 레지스트리에 접근하려면 `daemon.json`에 등록해야 한다(사내망처럼 신뢰된 네트워크가 아니면 권장하지 않는다).

```json
{ "insecure-registries": ["registry.internal:5000"] }
```



# 4. 인증과 credential helper
---

```bash
docker login registry.example.com
docker logout registry.example.com
```

비밀번호가 평문으로 `~/.docker/config.json`에 남는 걸 피하려면 credential helper(OS 키체인 연동)를 쓴다.

```bash
sudo dnf install docker-credential-pass
```

```json
{ "credsStore": "pass" }
```



# 5. 이미지 서명과 검증
---

Docker 자체의 **Docker Content Trust**(`DOCKER_CONTENT_TRUST=1`, `docker trust sign`)는 공식적으로 폐기(deprecated)가 예고돼 있어, 신규로는 CNCF Sigstore 생태계의 **cosign**을 쓰는 쪽이 표준이 되고 있다. cosign은 별도 개인 키를 직접 관리하지 않는 keyless 서명(OIDC 신원 기반 단기 인증서 + Rekor 투명성 로그)을 지원한다.

```bash
cosign sign registry.example.com/myteam/tempapp:1.0
cosign verify registry.example.com/myteam/tempapp:1.0
```

공급망 보안이 중요한 CI/CD 파이프라인에서는 "서명되지 않은 이미지는 배포 거부"라는 정책을 이런 도구로 강제한다.



# 6. CI/CD 파이프라인 연결
---

CI가 빌드부터 push까지 자동화하는 전형적인 흐름이다.

```bash
docker buildx build -t registry.example.com/myteam/tempapp:"$CI_COMMIT_SHA" --push .
```

`--push`는 buildx가 빌드 직후 바로 레지스트리로 밀어넣게 한다. 태그에 커밋 해시를 넣어 `latest`에 의존하지 않고 정확히 어떤 커밋이 배포됐는지 추적 가능하게 하는 게 일반적인 관행이다.



# 7. 실습
---

```bash
docker run -d -p 5000:5000 --name registry registry:3

docker build -t localhost:5000/tempapp:1.0 -<<'EOF'
FROM alpine:3.20
CMD ["echo", "hello from tempapp"]
EOF

docker push localhost:5000/tempapp:1.0
docker rmi localhost:5000/tempapp:1.0
docker pull localhost:5000/tempapp:1.0
docker run --rm localhost:5000/tempapp:1.0

docker rm -f registry
```



# 8. 참고 링크
---

─ CNCF Distribution — <https://distribution.github.io/distribution/>  
─ Docker Content Trust (deprecated) — <https://docs.docker.com/engine/security/trust/>  
─ cosign — <https://docs.sigstore.dev/cosign/signing/overview/>
