
---

***index***

[1. 네트워크 드라이버 종류](#1-네트워크-드라이버-종류)  
[2. 기본 bridge 네트워크와 docker0](#2-기본-bridge-네트워크와-docker0)  
[3. 포트 게시와 NAT](#3-포트-게시와-nat)  
[4. 사용자 정의 bridge와 내장 DNS](#4-사용자-정의-bridge와-내장-dns)  
[5. 컨테이너 간 통신](#5-컨테이너-간-통신)  
[6. host와 none 네트워크 모드](#6-host와-none-네트워크-모드)  
[7. macvlan과 ipvlan](#7-macvlan과-ipvlan)  
[8. 실습](#8-실습)  
[9. 참고 링크](#9-참고-링크)

---

Docker 네트워킹은 새로운 개념이 아니라 [네트워킹과 iptables/nftables](/linux/networking-and-firewall/)에서 다룬 bridge·Network Namespace·nftables NAT를 dockerd가 대신 조작해주는 것이다.



# 1. 네트워크 드라이버 종류
---

| 드라이버 | 특징 |
| :-- | :-- |
| bridge (기본) | 호스트 안의 가상 네트워크. NAT를 거쳐 외부와 통신 |
| host | 컨테이너가 호스트의 Network Namespace를 그대로 공유 |
| none | 루프백 외 네트워크 인터페이스 없음 |
| overlay | Docker Swarm에서 여러 호스트의 데몬을 하나의 네트워크로 연결 |
| macvlan / ipvlan | 컨테이너에 물리 네트워크의 실제 주소를 직접 부여 |



# 2. 기본 bridge 네트워크와 docker0
---

dockerd를 설치하면 `docker0`라는 Linux bridge 인터페이스가 생긴다. 네트워크를 따로 지정하지 않고 띄운 컨테이너는 이 `docker0`에 veth pair로 연결된다.

```bash
ip addr show docker0
docker network ls
docker network inspect bridge
```



# 3. 포트 게시와 NAT
---

`-p 8080:80`은 호스트 8080으로 들어온 트래픽을 컨테이너 80으로 넘긴다. 마법이 아니라 [nftables 구조](/linux/networking-and-firewall/)에서 다룬 DNAT 규칙을 dockerd가 대신 만들어주는 것이다.

```bash
docker run -d -p 8080:80 --name tempweb nginx:alpine
sudo nft list ruleset | grep -A3 -i docker    # dockerd가 만든 NAT 체인 확인
sudo iptables -t nat -L DOCKER -n              # 같은 내용을 iptables 형식으로
```

firewalld를 함께 쓰는 호스트에서는 Docker가 만드는 이 규칙이 firewalld의 zone 정책보다 먼저 평가되곤 한다 — firewalld에서 분명히 막은 포트가 Docker 컨테이너에는 그대로 열려 있는 것처럼 보이는 사고가 흔한 이유다. Docker는 자체 규칙보다 먼저 평가되는 `DOCKER-USER` 체인을 사용자용 훅으로 제공하므로, 컨테이너 트래픽에 대한 예외·차단 규칙은 여기에 넣는다.

```bash
sudo nft insert rule ip filter DOCKER-USER ip saddr 203.0.113.0/24 accept
sudo nft insert rule ip filter DOCKER-USER drop
```



# 4. 사용자 정의 bridge와 내장 DNS
---

기본 `bridge` 네트워크의 컨테이너는 서로 IP로만 찾을 수 있다. **사용자 정의 bridge**는 컨테이너 이름으로 자동 DNS 해석이 된다는 점이 결정적으로 다르다 — 그래서 실무에서는 기본 네트워크를 그대로 쓰지 않고 항상 네트워크를 따로 만든다.

```bash
docker network create tempnet
docker run -d --network tempnet --name db postgres:16-alpine
docker run -d --network tempnet --name web nginx:alpine
docker exec web getent hosts db     # 이름으로 바로 조회됨
```



# 5. 컨테이너 간 통신
---

같은 네트워크에 속한 컨테이너는 기본적으로 서로 전부 통신할 수 있다. "이 컨테이너는 저 컨테이너와만 통신 가능"처럼 세밀한 제어는 Docker 단독 기능만으로는 부족해 네트워크를 여러 개로 나눠 격리하는 정도로 대응한다 — Kubernetes의 NetworkPolicy가 이 세밀한 제어를 표준화한 것이다.



# 6. host와 none 네트워크 모드
---

```bash
docker run -d --network host --name tempweb nginx:alpine        # 호스트 Network Namespace 그대로 공유
docker run -d --network none --name tempisolated alpine sleep 3600   # 루프백 외 인터페이스 없음
```

`--network host`는 [Namespace 종류](/linux/namespace-and-cgroups/)에서 다룬 Network Namespace 자체를 격리하지 않는다는 뜻이다 — NAT를 거치지 않아 성능은 좋지만 그만큼 격리를 포기하는 트레이드오프다. 이 모드에서는 `-p`로 포트를 게시할 필요도, 의미도 없다(컨테이너가 호스트 포트를 직접 연다).



# 7. macvlan과 ipvlan
---

컨테이너에 물리 네트워크의 실제 IP를 직접 할당해, 네트워크 관점에서 별도 물리 장비처럼 보이게 한다. bridge+NAT를 거치지 않아 특정 IP를 직접 요구하는 레거시 애플리케이션에 쓴다. 다만 대부분의 클라우드 환경은 이런 임의 MAC·IP 할당을 제한하므로 클라우드에서는 잘 쓰지 않는다.



# 8. 실습
---

```bash
docker network create tempnet

docker run -d --network tempnet --name db postgres:16-alpine -e POSTGRES_PASSWORD=temp
docker run -d --network tempnet -p 8080:80 --name web nginx:alpine

docker exec web getent hosts db
docker exec web ping -c1 db

# 포트 게시가 만든 NAT 규칙 확인
sudo nft list ruleset | grep -i docker | head

docker rm -f web db
docker network rm tempnet
```



# 9. 참고 링크
---

─ Networking overview — <https://docs.docker.com/engine/network/>  
─ Bridge network driver — <https://docs.docker.com/engine/network/drivers/bridge/>  
─ Packet filtering and firewalls — <https://docs.docker.com/engine/network/packet-filtering-firewalls/>
