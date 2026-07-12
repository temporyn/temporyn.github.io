
---

***index***

[1. Pod란](#1-pod란)  
[2. 자원 공유](#2-자원-공유)  
[3. 컨테이너 구성](#3-컨테이너-구성)  
─ [3.1 init 컨테이너](#31-init-컨테이너)  
─ [3.2 사이드카(sidecar)](#32-사이드카sidecar)  
[4. Pod는 일회용이다](#4-pod는-일회용이다)  
[5. 워크로드 리소스](#5-워크로드-리소스)  
[6. 매니페스트](#6-매니페스트)  
─ [6.1 name과 labels](#61-name과-labels)  
[7. 리소스와 QoS](#7-리소스와-qos)  
[8. 생명주기](#8-생명주기)  
─ [8.1 phase](#81-phase)  
─ [8.2 컨테이너 상태](#82-컨테이너-상태)  
─ [8.3 restartPolicy](#83-restartpolicy)  
─ [8.4 probe](#84-probe)  
─ [8.5 conditions](#85-conditions)  
─ [8.6 라이프사이클 훅](#86-라이프사이클-훅)  
─ [8.7 종료](#87-종료)  
[9. 실습: 명령형으로 Pod 다루기](#9-실습-명령형으로-pod-다루기)  
[10. 실습: YAML로 Pod 만들기 (선언형)](#10-실습-yaml로-pod-만들기-선언형)  
[11. 실습: 다중 컨테이너 + Volume 공유](#11-실습-다중-컨테이너--volume-공유)  
[12. 디버깅](#12-디버깅)  
[13. 참고: 스태틱 Pod](#13-참고-스태틱-pod)  
[14. 참고 링크](#14-참고-링크)

---



# 1. Pod란
---

Pod는 **배포 가능한 최소 단위**이며, 하나 이상의 컨테이너 + 공유 storage·네트워크 + 실행 명세를 묶은 것이다. 쿠버네티스는 컨테이너를 개별로 실행하지 않고 항상 Pod에 담아 실행한다 — 컨테이너가 1개여도 Pod에 들어간다. 한 Pod 안의 컨테이너들은 네트워크·(설정 시)storage를 공유하고, 항상 같은 노드[^node]에 함께 배치·실행된다.

가장 흔한 형태는 컨테이너 1개짜리 Pod다. 이 경우 Pod는 단일 컨테이너를 감싸는 래퍼로, 대개 "Pod ≈ 컨테이너 1개"로 봐도 된다.

```text
+-------------------------+
| Pod                     |
|  +-------------------+  |
|  | Container (nginx) |  |
|  +-------------------+  |
|  shared IP / storage    |
+-------------------------+
```

→ 한 Pod가 컨테이너를 감싸고, IP·storage를 공유한다.



# 2. 자원 공유
---

Pod는 하나의 애플리케이션에 대한 "논리적 호스트"다. 한 서버 위의 프로세스들이 `localhost`로 통신하고 같은 디스크를 공유하듯 동작한다.

**네트워크** — 같은 네트워크 Namespace를 공유한다. IP 주소 하나를 공유하고(컨테이너별 IP 없음), 포트 공간도 공유해 같은 Pod 안에서 같은 포트를 중복해 쓸 수 없다. 컨테이너끼리는 `localhost`로 호출한다. 이 공유는 **pause 컨테이너**[^pause]가 Namespace를 대표로 잡아 유지하기 때문에 가능하며, 앱 컨테이너가 재시작돼도 Pod IP는 유지된다.

**storage** — Pod에 **Volume** 을 정의하면 여러 컨테이너가 같은 Volume을 마운트해 파일을 공유한다.



# 3. 컨테이너 구성
---

| 구분 | 설명 |
|:-----|:-----|
| **단일 컨테이너** | 가장 흔한 형태. Pod = 컨테이너 래퍼. |
| **다중 컨테이너** | 긴밀히 결합된 경우만 사용. 사이드카(sidecar) 패턴이 대표적(앱 + 로그 수집 등). |
| **init 컨테이너** | 앱 컨테이너보다 먼저, 순서대로, 완료될 때까지 실행되는 준비용 컨테이너. |

독립적으로 확장·배포돼야 하는 것들은 각각 **별도 Pod**로 둔다. 예를 들어 웹 서버와 DB는 한 Pod에 넣지 않는다.

## 3.1 init 컨테이너

앱 컨테이너보다 **먼저, 정의된 순서대로, 각자 성공(exit 0)해야** 다음으로 넘어간다. 하나라도 실패하면 `restartPolicy`에 따라 Pod를 재시작하며 init을 처음부터 다시 돈다. 설정 내려받기, 의존 서비스 대기 같은 준비 작업에 쓴다.

```yaml
spec:
  initContainers:
    - name: wait-db
      image: busybox:1.36
      command: ["sh", "-c", "until nc -z db 5432; do sleep 1; done"]
  containers:
    - name: app
      image: myapp:1.0
```

## 3.2 사이드카(sidecar)

앱 컨테이너와 **수명을 함께하며 나란히 도는** 보조 컨테이너(로그 수집·프록시 등). 네이티브 sidecar는 `initContainers`에 `restartPolicy: Always`를 준 것으로 정의한다 — 일반 init과 달리 계속 실행되고, probe도 붙일 수 있으며, 종료 시 앱 컨테이너보다 나중에 내려간다. v1.29에서 기본 활성(beta), v1.33 GA.

```yaml
spec:
  containers:
    - name: app
      image: myapp:1.0
  initContainers:
    - name: log-shipper
      image: busybox:1.36
      restartPolicy: Always            # 이 줄이 sidecar로 만든다
      command: ["sh", "-c", "tail -F /var/log/app.log"]
```



# 4. Pod는 일회용이다
---

| 특징                 | 내용                                               |
| ------------------ | ------------------------------------------------ |
| self-healing 없음    | 노드 장애·축출 시 그 Pod는 사라진다.                          |
| 노드 고정              | 한 번 배치되면 다른 노드로 옮겨지지 않고, 삭제 후 **새 Pod로 교체**된다.   |
| 교체 = 다른 개체         | 이름이 같아도 **다른 UID**다. 딸린 Volume도 UID에 묶여 함께 사라진다. |
| 컨테이너 재시작 ≠ Pod 재시작 | Pod는 프로세스가 아니라 컨테이너 실행 환경이다.                     |



# 5. 워크로드 리소스
---

일회용이라 실무에서는 Pod를 직접 만들지 않고 **워크로드 리소스**로 관리한다. "이 Pod를 항상 3개 유지"처럼 원하는 상태를 선언하면 controller가 Pod가 죽을 때마다 새로 만들어 맞춘다.

| 리소스 | 용도 |
|:-------|:-----|
| **Deployment** | 무상태 앱을 원하는 개수만큼 유지·업데이트. 가장 많이 씀. |
| **StatefulSet** | 상태가 있는 앱(고유 식별자·저장소 필요, DB 등). |
| **Job** | 한 번 실행 후 끝나는 배치 작업. |
| **CronJob** | 스케줄에 따라 반복 실행. |
| **DaemonSet** | 모든(또는 특정) 노드마다 Pod 하나씩 배치. |

Pod의 명세(`spec`)는 이 리소스들의 설정 안에 그대로 들어간다. 그래서 Pod를 알아야 그 위 개념을 이해할 수 있고, 학습·디버깅에는 Pod를 직접 다루는 것이 유용하다.



# 6. 매니페스트
---

가장 단순한 Pod 정의다.

```yaml
apiVersion: v1          # Pod는 핵심 그룹이라 'v1'
kind: Pod               # 리소스 종류
metadata:
  name: nginx           # 이름 (Namespace 안에서 유일)
  labels:
    app: web            # label: 이 Pod를 골라내기 위한 꼬리표
spec:
  containers:
    - name: nginx
      image: nginx:1.27       # 사용할 이미지
      ports:
        - containerPort: 80   # 컨테이너가 여는 포트
```

최상위 4개 키로 이뤄진다.

| 키 | 역할 |
|:--|:--|
| `apiVersion` / `kind` | 리소스 종류 |
| `metadata` | 이름·label 등 신원 |
| `spec` | 무엇을 어떻게 실행할지 (핵심) |

쿠버네티스는 **선언형(declarative)** 이다. "원하는 상태(spec)"를 적으면 현재 상태를 그 상태로 맞춘다.

## 6.1 name과 labels

둘 다 `metadata`에 들어가지만 역할이 정반대다.

| | name | labels |
|:--|:--|:--|
| 형태 | 문자열 하나 | 임의의 key-value 여러 개 |
| 유일성 | 같은 Namespace·같은 종류 안에서 유일 | 유일할 필요 없음(여러 개체가 같은 값 공유) |
| 개수 | 개체당 하나(필수) | 0개 이상(선택) |
| 용도 | 개체 하나를 콕 집어 지목 | 개체 무리를 조건으로 골라냄 |

**name**은 그 Pod의 고유 주소다. `kubectl get pod nginx`, `kubectl delete pod nginx`처럼 특정 개체를 다룰 때 이 이름으로 지목한다. 한 Namespace 안에서 같은 종류끼리 중복될 수 없고, 만들고 나면 바꿀 수 없다.

**labels**은 개체에 붙이는 꼬리표다. 이름과 달리 여러 Pod에 같은 label(`app: web`)을 달아 하나의 무리로 묶을 수 있다. Service·Deployment 같은 상위 리소스는 개별 이름이 아니라 **label selector**로 대상 Pod를 고른다 — 예를 들어 Service는 `app: web`이 붙은 Pod 전부를 트래픽 대상으로 잡는다. 그래서 Pod가 죽고 이름이 다른 새 Pod로 교체돼도, 같은 label만 달려 있으면 selector에 그대로 걸린다.

정리하면 name은 "이 개체 하나"를 가리키는 식별자, label은 "이런 조건에 맞는 개체들"을 묶는 분류 태그다.



# 7. 리소스와 QoS
---

컨테이너에 `resources.requests`/`limits`를 주면 노드 자원 압박 시 축출·OOM 순서를 정하는 **QoS 클래스**가 자동으로 결정된다.

`requests`는 스케줄러가 배치할 노드를 고르는 기준이자 **예약량**, `limits`는 **상한**이다. CPU가 limits를 넘으면 throttle(감속)되고, memory가 limits를 넘으면 **OOMKilled**로 종료된다.

```yaml
containers:
  - name: app
    image: myapp:1.0
    resources:
      requests:            # 최소 예약 (스케줄링 기준)
        cpu: "250m"        # 0.25 core
        memory: "128Mi"
      limits:              # 상한 (초과 시 CPU는 throttle, memory는 OOMKilled)
        cpu: "500m"
        memory: "256Mi"
```

| QoS | 조건 | 축출 우선순위 |
|:----|:-----|:-----|
| **Guaranteed** | 모든 컨테이너가 CPU·memory 각각 `requests == limits`(둘 다 > 0) | 가장 나중(보호) |
| **Burstable** | Guaranteed는 아니고, 최소 한 컨테이너에 requests나 limits가 있음 | 중간 |
| **BestEffort** | 어떤 컨테이너에도 requests·limits가 없음 | 가장 먼저 |

노드 메모리가 부족하면 BestEffort → Burstable → Guaranteed 순으로 축출한다. 중요 워크로드는 `requests == limits`로 Guaranteed를 만든다.

`resources`만 떼어 세 클래스를 비교하면 다음과 같다.

**Guaranteed** — 모든 컨테이너가 CPU·memory 각각 `requests == limits`.

```yaml
resources:
  requests: {cpu: "500m", memory: "256Mi"}
  limits:   {cpu: "500m", memory: "256Mi"}   # requests와 완전히 동일
```

**Burstable** — requests나 limits는 있으나 Guaranteed 조건에 못 미침.

```yaml
resources:
  requests: {cpu: "250m", memory: "128Mi"}
  limits:   {memory: "256Mi"}                # 일부만·다르게 지정
```

**BestEffort** — 어떤 컨테이너에도 requests·limits가 없음.

```yaml
# resources 블록을 아예 두지 않는다
containers:
  - name: app
    image: myapp:1.0
```



# 8. 생명주기
---

## 8.1 phase

`status.phase` 값은 정확히 다섯 가지다.

| Phase | 의미 |
|:------|:-----|
| **Pending** | 받아들여졌으나 실행 준비 중(스케줄링·이미지 내려받기 등). |
| **Running** | 노드에 배치되어 모든 컨테이너 생성됨. 최소 하나가 실행/시작/재시작 중. |
| **Succeeded** | 모든 컨테이너가 성공 종료, 재시작 안 함. |
| **Failed** | 모든 컨테이너 종료, 최소 하나가 실패(0 아닌 코드)로 끝남. |
| **Unknown** | 노드 통신 불가 등으로 상태 알 수 없음. |

`CrashLoopBackOff`, `Terminating`, `ContainerCreating`은 `kubectl` 표시 상태일 뿐 phase가 아니다. `CrashLoopBackOff`는 컨테이너가 반복 종료되어 재시작 간격을 늘려 대기 중이라는 뜻이다.

## 8.2 컨테이너 상태

각 컨테이너는 **Waiting**(실행 전) / **Running**(실행 중) / **Terminated**(종료됨) 중 하나이고, 상태마다 `reason`이 붙는다.

| 상태 | reason | 뜻 |
|:-----|:-------|:---|
| Waiting | `ContainerCreating` | 생성 중(이미지·Volume 준비) |
| Waiting | `CrashLoopBackOff` | 반복 크래시로 재시작 간격을 늘려 대기 |
| Waiting | `ImagePullBackOff` | 이미지 내려받기 실패, 백오프 재시도 |
| Terminated | `Completed` | exit 0으로 정상 종료 |
| Terminated | `Error` | 0 아닌 코드로 종료 |
| Terminated | `OOMKilled` | 메모리 상한 초과로 커널이 종료 |

`kubectl get pod <pod> -o yaml`의 `status.containerStatuses`에서 상태와 `reason`이 드러난다.

```yaml
status:
  containerStatuses:
    - name: app
      ready: false
      restartCount: 5
      state:
        waiting:
          reason: CrashLoopBackOff
          message: 'back-off 40s restarting failed container'
```

## 8.3 restartPolicy

컨테이너 종료 시 재시작 여부. `spec.restartPolicy`, **기본값 `Always`**.

| 값 | 동작 |
|:---|:-----|
| **Always** (기본) | 성공이라도 항상 재시작. Deployment 등이 사용. |
| **OnFailure** | 실패했을 때만 재시작. Job에서 사용. |
| **Never** | 재시작 안 함. |

```yaml
spec:
  restartPolicy: OnFailure    # 실패(0 아닌 exit)일 때만 재시작 — Job에서 흔함
  containers:
    - name: batch
      image: myjob:1.0
```

## 8.4 probe

kubelet이 컨테이너를 주기적으로 점검한다.

| probe | 확인 | 실패 시 |
|:-------|:-----|:--------|
| **Liveness** | 장애 여부 | 컨테이너 **재시작** |
| **Readiness** | 요청 받을 준비됐나 | 트래픽 대상(Service endpoint)에서 **제외**(재시작 안 함) |
| **Startup** | 느린 앱이 다 켜졌나 | 성공 전까지 liveness/readiness **보류** |

점검 방식(handler)은 넷 중 하나다: `httpGet`(2xx·3xx면 성공), `tcpSocket`(연결되면 성공), `exec`(명령 exit 0이면 성공), `grpc`(gRPC 헬스 체크).

타이밍 필드와 기본값:

| 필드 | 기본 | 뜻 |
|:-----|:----:|:---|
| `initialDelaySeconds` | 0 | 첫 점검까지 대기 |
| `periodSeconds` | 10 | 점검 간격 |
| `timeoutSeconds` | 1 | 응답 타임아웃 |
| `successThreshold` | 1 | 성공 판정에 필요한 연속 성공 |
| `failureThreshold` | 3 | 실패 판정에 필요한 연속 실패 |

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

느린 기동은 `startupProbe`로 보호하고, handler는 `httpGet` 외에 `exec`·`tcpSocket`도 쓴다.

```yaml
startupProbe:               # 다 켜질 때까지 liveness/readiness 보류
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
  failureThreshold: 30      # 10s × 30 = 최대 300초까지 기동 대기
livenessProbe:
  exec:                     # 명령 exit 0이면 성공
    command: ["cat", "/tmp/healthy"]
readinessProbe:
  tcpSocket:                # 포트 연결되면 성공
    port: 3306
```

## 8.5 conditions

`status.conditions`가 진행 단계를 나타낸다: `PodScheduled`(배정) → `Initialized`(init 완료) → `ContainersReady`(모든 컨테이너 준비) → `Ready`(트래픽 수신 준비).

```yaml
status:
  phase: Running
  conditions:
    - type: PodScheduled
      status: "True"
    - type: Initialized
      status: "True"
    - type: ContainersReady
      status: "True"
    - type: Ready
      status: "True"
```

## 8.6 라이프사이클 훅

컨테이너 시작·종료 시점에 실행하는 훅. `exec` 또는 `httpGet`으로 건다.

**postStart** — 컨테이너 생성 직후 실행(ENTRYPOINT와 순서 보장 없음). 실패해도 컨테이너는 뜬다.

**preStop** — 종료 직전, **SIGTERM보다 먼저** 실행. 완료될 때까지 종료가 대기하므로 커넥션 정리·드레이닝에 쓴다.

```yaml
lifecycle:
  postStart:
    exec:
      command: ["sh", "-c", "echo ready > /tmp/started"]
  preStop:
    exec:
      command: ["sh", "-c", "nginx -s quit"]   # graceful 종료 신호
```

## 8.7 종료

Pod 삭제 시 순서: `Terminating` 표시 → **preStop 훅** 실행 → 컨테이너에 **SIGTERM** → 유예 시간(기본 **30초**, `terminationGracePeriodSeconds`) 대기 → 안 끝나면 **SIGKILL**. preStop과 SIGTERM 처리는 이 유예 시간을 나눠 쓴다.

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sh", "-c", "sleep 15"]   # 드레이닝 후 종료
```



# 9. 실습: 명령형으로 Pod 다루기
---

minikube 클러스터가 실행 중이어야 한다(`kubectl get nodes`).

```bash
# 생성
kubectl run my-nginx --image=nginx:1.27

# 상태 (STATUS가 Running이 될 때까지 잠시 걸림)
kubectl get pods
kubectl get pods -o wide       # IP·배치 노드까지
kubectl get pods -w            # 실시간 감시 (Ctrl+C)

# 상세 정보 + 이벤트 (디버깅 1순위, 맨 아래 Events 확인)
kubectl describe pod my-nginx

# 로그
kubectl logs my-nginx
kubectl logs my-nginx -f       # 실시간

# 컨테이너 내부 진입
kubectl exec -it my-nginx -- bash

# 로컬 8080 → Pod 80 연결 후 http://localhost:8080 접속
kubectl port-forward pod/my-nginx 8080:80

# 삭제
kubectl delete pod my-nginx
```



# 10. 실습: YAML로 Pod 만들기 (선언형)
---

`my-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

```bash
kubectl apply -f my-pod.yaml   # 생성/갱신
kubectl get pods
kubectl get pod web -o yaml     # 기본값까지 채워진 전체 정의 확인
kubectl delete -f my-pod.yaml
```



# 11. 실습: 다중 컨테이너 + Volume 공유
---

`writer`가 파일에 시간을 쓰고 `web`(nginx)이 같은 Volume을 서빙한다.

`shared-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared
spec:
  volumes:
    - name: html
      emptyDir: {}                # Pod와 수명을 함께하는 임시 디렉터리
  containers:
    - name: writer
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args:
        - while true; do date > /data/index.html; sleep 1; done
      volumeMounts:
        - name: html
          mountPath: /data
    - name: web
      image: nginx:1.27
      volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
```

```bash
kubectl apply -f shared-pod.yaml
kubectl get pod shared              # READY 2/2 확인
kubectl port-forward pod/shared 8080:80   # 새로고침마다 시간 갱신
kubectl logs shared -c writer       # -c로 컨테이너 지정
kubectl delete -f shared-pod.yaml
```

<http://localhost:8080> 을 새로고침할 때마다 시간이 갱신되면, `writer`가 쓴 파일을 `web`이 같은 Volume으로 읽고 있다는 뜻이다.



# 12. 디버깅
---

```bash
kubectl describe pod <pod>          # 맨 아래 Events가 1순위
kubectl logs <pod>                  # 현재 컨테이너 로그
kubectl logs <pod> --previous       # 크래시 직전(이전 인스턴스) 로그
kubectl logs <pod> -c <container>   # 다중 컨테이너 중 하나 지정
```

이미지에 셸·도구가 없어 `exec`가 막힐 때는 **ephemeral 컨테이너**로 진단한다. 실행 중인 Pod에 임시 컨테이너를 얹는 것이라 앱을 재시작하지 않고, Pod의 Namespace(프로세스·네트워크·파일)를 공유한다.

```bash
kubectl debug <pod> -it --image=busybox:1.36    # 임시 컨테이너로 진입
```



# 13. 참고: 스태틱 Pod
---

API 서버를 거치지 않고 **노드의 kubelet이 직접 관리**하는 Pod다. 노드의 지정 디렉터리에 YAML을 두면 kubelet이 띄운다. 주로 Control Plane 자체를 부트스트랩하는 데 쓰고, 일반 애플리케이션 배포용은 아니다.



# 14. 참고 링크
---

| 항목           | 링크                                                                     |
| ------------ | ---------------------------------------------------------------------- |
| Pods         | <https://kubernetes.io/ko/docs/concepts/workloads/pods/>               |
| Pod 생명주기     | <https://kubernetes.io/ko/docs/concepts/workloads/pods/pod-lifecycle/> |
| kubectl 치트시트 | <https://kubernetes.io/ko/docs/reference/kubectl/cheatsheet/>          |

***각주***

[^node]: 노드(Node)는 컨테이너가 실제로 실행되는 서버 한 대(물리 또는 가상 머신)다. 클러스터는 이런 노드 여러 대로 이뤄지고, Pod는 그중 한 노드 위에서 돈다.
[^pause]: 쿠버네티스가 Pod마다 자동으로 띄우는 숨은 컨테이너. 아무 일도 하지 않고 정지(pause) 상태로 네트워크 Namespace만 붙들어, 앱 컨테이너들이 여기에 얹혀 같은 IP를 공유하게 한다.

