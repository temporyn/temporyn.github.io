# Pod

> 선행: [준비 과정](/kubernetes/Prepared/)의 minikube 클러스터와 `kubectl`이 필요하다.

쿠버네티스의 최소 배포 단위인 **Pod(파드)**. 개념 → 매니페스트 → 생명주기 → 실습 순으로 다룬다.

---

## Pod란

Pod는 **배포 가능한 최소 단위**이며, 하나 이상의 컨테이너 + 공유 스토리지·네트워크 + 실행 명세를 묶은 것이다. 핵심은 두 가지다.

- 쿠버네티스는 컨테이너를 개별로 실행하지 않는다. 항상 Pod에 담아 실행하며, 컨테이너가 1개여도 Pod에 들어간다.
- 한 Pod 안의 컨테이너들은 네트워크·(설정 시)스토리지를 공유하고, 항상 같은 노드[^node]에 함께 배치·실행된다.

가장 흔한 형태는 컨테이너 1개짜리 Pod다. 이 경우 Pod는 단일 컨테이너를 감싸는 래퍼로, 대개 "Pod ≈ 컨테이너 1개"로 봐도 된다.

```text
┌─────────────────────────┐
│ Pod                     │
│  ┌───────────────────┐  │
│  │ Container (nginx) │  │
│  └───────────────────┘  │
│  shared IP / storage    │
└─────────────────────────┘
```

→ 한 Pod가 컨테이너를 감싸고, IP·스토리지를 공유한다.

---

## 자원 공유

Pod는 하나의 애플리케이션에 대한 "논리적 호스트"다. 한 서버 위의 프로세스들이 `localhost`로 통신하고 같은 디스크를 공유하듯 동작한다.

**네트워크** — 같은 네트워크 네임스페이스를 공유한다.

- IP 주소 하나를 공유한다(컨테이너별 IP 없음).
- 포트 공간을 공유한다 → 같은 Pod 안에서 같은 포트를 중복해 쓸 수 없다.
- 서로를 `localhost`로 호출한다.
- 이 공유는 **pause 컨테이너**[^pause]가 네임스페이스를 대표로 잡아 유지하기 때문에 가능하다. 앱 컨테이너가 재시작돼도 Pod IP는 유지된다.

**스토리지** — Pod에 **볼륨(Volume)** 을 정의하면 여러 컨테이너가 같은 볼륨을 마운트해 파일을 공유한다.

---

## 컨테이너 구성

| 구분 | 설명 |
|:-----|:-----|
| **단일 컨테이너** | 가장 흔한 형태. Pod = 컨테이너 래퍼. |
| **다중 컨테이너** | 긴밀히 결합된 경우만 사용. 사이드카(sidecar) 패턴이 대표적(앱 + 로그 수집 등). |
| **init 컨테이너** | 앱 컨테이너보다 먼저, 순서대로, 완료될 때까지 실행되는 준비용 컨테이너. |

독립적으로 확장·배포돼야 하는 것들은 각각 **별도 Pod**로 둔다. 예를 들어 웹 서버와 DB는 한 Pod에 넣지 않는다.

---

## Pod는 일회용이다

- **스스로 복구(self-healing)하지 않는다.** 노드 장애·축출 시 그 Pod는 사라진다.
- 특정 노드에 한 번 배치되면 다른 노드로 옮겨지지 않는다. 삭제 후 **새 Pod로 교체**된다.
- 교체된 Pod는 이름이 같아도 **다른 UID**를 가진 다른 개체다. 딸린 볼륨도 UID에 묶여 함께 사라진다.
- 컨테이너 재시작 ≠ Pod 재시작. Pod는 프로세스가 아니라 컨테이너 실행 환경이다.

---

## 워크로드 리소스

일회용이라 실무에서는 Pod를 직접 만들지 않고 **워크로드 리소스**로 관리한다. "이 Pod를 항상 3개 유지"처럼 원하는 상태를 선언하면 컨트롤러가 Pod가 죽을 때마다 새로 만들어 맞춘다.

| 리소스 | 용도 |
|:-------|:-----|
| **Deployment** | 무상태 앱을 원하는 개수만큼 유지·업데이트. 가장 많이 씀. |
| **StatefulSet** | 상태가 있는 앱(고유 식별자·저장소 필요, DB 등). |
| **Job** | 한 번 실행 후 끝나는 배치 작업. |
| **CronJob** | 스케줄에 따라 반복 실행. |
| **DaemonSet** | 모든(또는 특정) 노드마다 Pod 하나씩 배치. |

Pod의 명세(`spec`)는 이 리소스들의 설정 안에 그대로 들어간다. 그래서 Pod를 알아야 그 위 개념을 이해할 수 있고, 학습·디버깅에는 Pod를 직접 다루는 것이 유용하다.

---

## 매니페스트

가장 단순한 Pod 정의다.

```yaml
apiVersion: v1          # Pod는 핵심 그룹이라 'v1'
kind: Pod               # 리소스 종류
metadata:
  name: nginx           # 이름 (네임스페이스 안에서 유일)
  labels:
    app: web            # 라벨: 이 Pod를 골라내기 위한 꼬리표
spec:
  containers:
    - name: nginx
      image: nginx:1.27       # 사용할 이미지
      ports:
        - containerPort: 80   # 컨테이너가 여는 포트
```

최상위 4개 키로 이뤄진다.

- `apiVersion` / `kind` — 리소스 종류
- `metadata` — 이름·라벨 등 신원
- `spec` — 무엇을 어떻게 실행할지 (핵심)

쿠버네티스는 **선언형(declarative)** 이다. "원하는 상태(spec)"를 적으면 현재 상태를 그 상태로 맞춘다.

---

## 생명주기

### phase

`status.phase` 값은 정확히 다섯 가지다.

| Phase | 의미 |
|:------|:-----|
| **Pending** | 받아들여졌으나 실행 준비 중(스케줄링·이미지 내려받기 등). |
| **Running** | 노드에 배치되어 모든 컨테이너 생성됨. 최소 하나가 실행/시작/재시작 중. |
| **Succeeded** | 모든 컨테이너가 성공 종료, 재시작 안 함. |
| **Failed** | 모든 컨테이너 종료, 최소 하나가 실패(0 아닌 코드)로 끝남. |
| **Unknown** | 노드 통신 불가 등으로 상태 알 수 없음. |

`CrashLoopBackOff`, `Terminating`, `ContainerCreating`은 `kubectl` 표시 상태일 뿐 phase가 아니다. `CrashLoopBackOff`는 컨테이너가 반복 종료되어 재시작 간격을 늘려 대기 중이라는 뜻이다.

### 컨테이너 상태

각 컨테이너는 **Waiting**(실행 전) / **Running**(실행 중) / **Terminated**(종료됨) 중 하나다.

### restartPolicy

컨테이너 종료 시 재시작 여부. `spec.restartPolicy`, **기본값 `Always`**.

| 값 | 동작 |
|:---|:-----|
| **Always** (기본) | 성공이라도 항상 재시작. Deployment 등이 사용. |
| **OnFailure** | 실패했을 때만 재시작. Job에서 사용. |
| **Never** | 재시작 안 함. |

### 프로브

kubelet이 컨테이너를 주기적으로 점검한다.

| 프로브 | 확인 | 실패 시 |
|:-------|:-----|:--------|
| **Liveness** | 장애 여부 | 컨테이너 **재시작** |
| **Readiness** | 요청 받을 준비됐나 | 트래픽 대상에서 **제외**(재시작 안 함) |
| **Startup** | 느린 앱이 다 켜졌나 | 성공 전까지 liveness/readiness **보류** |

### conditions

`status.conditions`가 진행 단계를 나타낸다: `PodScheduled`(배정) → `Initialized`(init 완료) → `ContainersReady`(모든 컨테이너 준비) → `Ready`(트래픽 수신 준비).

### 종료

Pod 삭제 시: `Terminating` → 컨테이너에 **SIGTERM** → 유예 시간(기본 **30초**, `terminationGracePeriodSeconds`) 대기 → 안 끝나면 **SIGKILL**.

---

## 실습 1: 명령형으로 Pod 다루기

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

---

## 실습 2: YAML로 Pod 만들기 (선언형)

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

---

## 실습 3: 다중 컨테이너 + 볼륨 공유

`writer`가 파일에 시간을 쓰고 `web`(nginx)이 같은 볼륨을 서빙한다.

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

<http://localhost:8080> 을 새로고침할 때마다 시간이 갱신되면, `writer`가 쓴 파일을 `web`이 같은 볼륨으로 읽고 있다는 뜻이다.

---

## 참고: 스태틱 Pod

API 서버를 거치지 않고 **노드의 kubelet이 직접 관리**하는 Pod다. 노드의 지정 디렉터리에 YAML을 두면 kubelet이 띄운다. 주로 컨트롤 플레인 자체를 부트스트랩하는 데 쓰고, 일반 애플리케이션 배포용은 아니다.

---

## 참고 링크

- Pods: <https://kubernetes.io/ko/docs/concepts/workloads/pods/>
- Pod 생명주기: <https://kubernetes.io/ko/docs/concepts/workloads/pods/pod-lifecycle/>
- kubectl 치트시트: <https://kubernetes.io/ko/docs/reference/kubectl/cheatsheet/>

[^node]: 노드(Node)는 컨테이너가 실제로 실행되는 서버 한 대(물리 또는 가상 머신)다. 클러스터는 이런 노드 여러 대로 이뤄지고, Pod는 그중 한 노드 위에서 돈다.
[^pause]: 쿠버네티스가 Pod마다 자동으로 띄우는 숨은 컨테이너. 아무 일도 하지 않고 정지(pause) 상태로 네트워크 네임스페이스만 붙들어, 앱 컨테이너들이 여기에 얹혀 같은 IP를 공유하게 한다.
