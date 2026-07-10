# ConfigMap과 Secret

> 선행: [Pod](/kubernetes/Pod/), [Volume](/kubernetes/Volume/), minikube 클러스터.

설정을 이미지에서 분리해 주입하는 **ConfigMap**과, 민감정보를 담는 **Secret**. 둘은 만드는 법과 소비 방식이 거의 같고, 용도(민감성)와 저장 방식만 다르다.

---

## ConfigMap란

**ConfigMap**은 비밀이 아닌 **설정 데이터를 key-value로 저장**하는 객체다. 설정을 컨테이너 이미지에서 떼어내, 같은 이미지를 개발·운영 등 환경마다 다른 설정으로 재사용하게 한다.

- **민감정보용이 아니다.** 비밀번호·토큰·키는 **Secret**을 쓴다(ConfigMap은 암호화되지 않음).
- **크기 제한 1 MiB.** 큰 데이터를 담는 용도가 아니다.
- Pod와 **같은 네임스페이스**여야 참조할 수 있다. 스태틱 Pod는 참조 불가.
- 필드: `data`(UTF-8 문자열), `binaryData`(base64 바이너리). 키는 영숫자·`-`·`_`·`.`만.

### 만들기

명령형(`kubectl create configmap`):

```bash
# 리터럴 값으로
kubectl create configmap game-demo \
  --from-literal=player_lives=3 \
  --from-literal=ui_file=user-interface.properties

# 파일/디렉터리로
kubectl create configmap game-demo --from-file=game.properties
kubectl create configmap game-demo --from-file=./config/
```

선언형(YAML):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: game-demo
data:
  player_lives: "3"                 # 단순 key-value
  game.properties: |                # 파일 형태의 여러 줄 값
    enemy.types=aliens,monsters
    player.maximum-lives=5
```

### 소비하는 4가지 방법

| 방법 | 필드 | 특징 |
|:-----|:-----|:-----|
| **① 개별 키 → 환경변수** | `env[].valueFrom.configMapKeyRef` | 원하는 키만 골라 환경변수로 |
| **② 전체 키 → 환경변수** | `envFrom[].configMapRef` | 모든 키를 한 번에 환경변수로 |
| **③ 커맨드 인자** | `$(VAR)` 참조 | 환경변수를 명령 인자에 사용 |
| **④ 볼륨 파일로 마운트** | `configMap` 볼륨 | 각 키가 파일 하나로. **읽기 전용** |

환경변수로 (①·②):

```yaml
spec:
  containers:
    - name: app
      image: alpine
      env:
        - name: PLAYER_LIVES               # ① 개별 키
          valueFrom:
            configMapKeyRef:
              name: game-demo
              key: player_lives
      envFrom:
        - configMapRef:                    # ② 전체 키
            name: game-demo
```

볼륨 파일로 (④):

```yaml
spec:
  containers:
    - name: app
      image: redis
      volumeMounts:
        - name: config
          mountPath: /etc/config           # 각 키가 이 아래 파일로 생성됨
          readOnly: true
  volumes:
    - name: config
      configMap:
        name: game-demo
        # items 생략 시 모든 키가 파일이 됨. 지정하면 그 키만.
```

### 갱신 동작

수정했을 때 반영 방식이 소비 방법마다 다르다(Secret도 동일).

| 소비 방법 | 자동 갱신 |
|:----------|:---------|
| **볼륨 마운트** | 됨 — kubelet 동기화로 결국 반영(단, `subPath` 마운트는 제외) |
| **환경변수** | 안 됨 — Pod 재시작 필요 |
| **커맨드 인자** | 안 됨 — Pod 재시작 필요 |

`immutable: true`로 만들면 수정 불가가 되고(실수 방지), kubelet이 감시를 줄여 성능에 유리하다.

---

## Secret란

**Secret**은 비밀번호·토큰·키 같은 **민감정보**를 담는 객체다. 이런 값을 Pod 명세나 이미지에 하드코딩하지 않게 한다. 구조·소비 방식은 ConfigMap과 거의 같다.

- **base64는 암호화가 아니라 인코딩이다.** 누구나 디코드할 수 있고, 기본적으로 etcd에 **평문(인코딩)으로 저장**된다. 안전하게 쓰려면 **저장 시 암호화(Encryption at Rest) + RBAC 최소 권한**을 건다. 어떤 네임스페이스에 Pod 생성 권한이 있으면 그 네임스페이스의 Secret을 읽을 수 있다.
- 필드: `data`(base64 값), `stringData`(평문 편의 필드 — write-only라 조회 시 안 보이고, 저장 시 자동 base64). 1 MiB 제한, `immutable` 지원.
- 타입: `Opaque`(기본, 임의 데이터), `kubernetes.io/basic-auth`, `kubernetes.io/ssh-auth`, `kubernetes.io/tls`, `kubernetes.io/dockerconfigjson` 등.

### 만들기

명령형(`kubectl create secret generic` → 타입 Opaque):

```bash
kubectl create secret generic db-cred \
  --from-literal=username=admin \
  --from-literal=password='s3cr3t'
```

선언형(YAML):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-cred
type: Opaque
stringData:            # 평문으로 쓰면 저장 시 자동 base64
  username: admin
  password: s3cr3t
# data: 로 직접 넣을 땐 base64 값. 예: echo -n admin | base64  → YWRtaW4=
```

### 소비

ConfigMap과 동일하게 환경변수·볼륨으로 소비하되, 참조 필드만 Secret용으로 바뀐다.

| 방법 | 필드 |
|:-----|:-----|
| 개별 키 → 환경변수 | `env[].valueFrom.secretKeyRef` |
| 전체 키 → 환경변수 | `envFrom[].secretRef` |
| 볼륨 파일 | `secret` 볼륨 (**tmpfs(RAM)** 로 마운트, Pod 삭제 시 정리) |

```yaml
spec:
  containers:
    - name: app
      image: nginx:1.27
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-cred
              key: password
      volumeMounts:
        - name: cred
          mountPath: /etc/cred
          readOnly: true
  volumes:
    - name: cred
      secret:
        secretName: db-cred
```

---

## ConfigMap vs Secret

| | ConfigMap | Secret |
|:--|:--|:--|
| 용도 | 일반 설정 | 민감정보 |
| 값 저장 | 평문(`data`/`binaryData`) | base64(`data`) / 평문 입력(`stringData`) |
| 볼륨 마운트 매체 | 노드 저장소 | **tmpfs(RAM)** |
| 참조 필드 | `configMapKeyRef` / `configMapRef` | `secretKeyRef` / `secretRef` |
| 타입 | 없음 | `Opaque` 등 |

크기 제한(1 MiB), 같은 네임스페이스 제약, 소비 4방식, 갱신 동작은 둘 다 같다.

---

## 실습: ConfigMap과 Secret 함께 소비

```bash
kubectl create configmap app-config --from-literal=GREETING=hello
kubectl create secret generic app-secret --from-literal=TOKEN=abc123
```

`cm-secret-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["/bin/sh", "-c", "sleep 3600"]
      env:
        - name: GREETING                   # ConfigMap → 환경변수
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: GREETING
        - name: TOKEN                       # Secret → 환경변수
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: TOKEN
      volumeMounts:
        - name: secret-vol
          mountPath: /etc/secret            # Secret → 파일(tmpfs)
          readOnly: true
  volumes:
    - name: secret-vol
      secret:
        secretName: app-secret
```

```bash
kubectl apply -f cm-secret-pod.yaml

kubectl exec demo -- printenv GREETING TOKEN     # → hello / abc123
kubectl exec demo -- cat /etc/secret/TOKEN       # → abc123
kubectl exec demo -- df -h /etc/secret           # tmpfs 로 마운트된 것 확인

kubectl delete -f cm-secret-pod.yaml
kubectl delete configmap app-config
kubectl delete secret app-secret
```

---

## 참고 링크

- ConfigMap: <https://kubernetes.io/ko/docs/concepts/configuration/configmap/>
- Secret: <https://kubernetes.io/ko/docs/concepts/configuration/secret/>
