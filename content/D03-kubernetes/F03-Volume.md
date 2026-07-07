# Volume

> 선행: [Pod](/kubernetes/Pod/), minikube 클러스터.

Pod에 파일 저장 공간을 붙이는 **Volume(볼륨)**.

---

## Volume란

컨테이너의 파일시스템은 **휘발성**이다. 컨테이너가 죽고 재시작되면 그 안에 쓴 파일은 초기 이미지 상태로 돌아가 사라진다. 또 한 Pod 안 여러 컨테이너가 파일을 주고받을 방법도 필요하다. **볼륨**은 이 둘을 해결한다.

- 컨테이너 파일시스템 밖에 있는 저장 공간을 Pod에 붙인다.
- 같은 Pod 안 여러 컨테이너가 같은 볼륨을 마운트해 파일을 공유한다.
- 볼륨 종류에 따라 수명이 다르다(Pod와 함께 사라지기도, Pod와 독립적으로 남기도).

---

## 선언과 마운트

볼륨은 두 곳에 적는다.

- `spec.volumes` — Pod 수준에서 볼륨을 **선언**한다.
- `spec.containers[].volumeMounts` — 각 컨테이너가 그 볼륨을 **어디에(`mountPath`)** 붙일지 지정한다.

```yaml
spec:
  volumes:
    - name: cache          # ① 볼륨 선언
      emptyDir: {}
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: cache      # ② 위 볼륨을
          mountPath: /data # ③ 이 경로에 마운트
```

컨테이너가 보는 파일시스템 = 이미지의 초기 내용 + 마운트된 볼륨들이다.

```text
        ┌──────── Pod ────────────┐
        │  volume: cache          │
        │    ├── /data (container A)
        │    └── /data (container B)   ← 같은 볼륨을 공유
        └─────────────────────────┘
```

---

## 주요 볼륨 타입

| 타입 | 용도 | 수명 |
|:-----|:-----|:-----|
| **emptyDir** | Pod 내 빈 디렉터리. 컨테이너 간 공유·임시 캐시. | Pod와 함께(컨테이너 재시작은 견딤) |
| **configMap** / **secret** | 설정·민감정보를 **읽기 전용 파일**로 주입. | 참조 대상에 종속 |
| **persistentVolumeClaim** | 영속 스토리지(PV)를 연결. | **Pod와 독립** |
| **downwardAPI** | Pod·컨테이너 필드 값을 읽기 전용 파일로 노출. | Pod와 함께 |
| **hostPath** | 노드의 파일/디렉터리를 마운트. 보안 위험이라 권장하지 않음. | 노드 |

### emptyDir 수명

- Pod가 노드에 배치될 때 **빈 상태로 생성**된다.
- 컨테이너가 크래시로 재시작돼도 **유지된다**(컨테이너 재시작 ≠ Pod 제거).
- Pod가 노드에서 제거되면 **영구 삭제**된다. → 임시 데이터용이지 영속 저장용이 아니다.
- `medium: Memory`로 두면 디스크 대신 RAM(tmpfs)에 올린다.

---

## 실습 1: emptyDir 공유

`writer`가 파일에 쓰고 `reader`가 읽어 같은 볼륨을 공유함을 확인한다.

`emptydir-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: share
spec:
  volumes:
    - name: data
      emptyDir: {}
  containers:
    - name: writer
      image: busybox:1.36
      command: ["/bin/sh", "-c", "echo hello-from-writer > /data/msg; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
    - name: reader
      image: busybox:1.36
      command: ["/bin/sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
```

```bash
kubectl apply -f emptydir-pod.yaml
kubectl get pod share                       # READY 2/2

# reader 컨테이너에서 writer가 쓴 파일을 읽는다
kubectl exec share -c reader -- cat /data/msg   # → hello-from-writer

kubectl delete -f emptydir-pod.yaml
```

---

## 영속 스토리지: PV / PVC

emptyDir 등은 Pod가 사라지면 함께 없어진다. Pod 수명과 **무관하게** 데이터를 남기려면 **PersistentVolume(PV)** 과 **PersistentVolumeClaim(PVC)** 을 쓴다.

- **PV** — 클러스터에 준비된 실제 저장소(NFS·클라우드 디스크 등). Pod와 독립된 수명.
- **PVC** — "이만큼의 저장소를 달라"는 **요청**. 조건이 맞는 PV에 1:1로 **바인딩**된다.
- **StorageClass** — PVC 요청에 맞춰 PV를 **자동 생성(동적 프로비저닝)**. 맞는 PV가 없고 StorageClass가 지정되면 볼륨이 즉석에서 만들어진다.

접근 모드(accessModes):

| 모드 | 뜻 |
|:-----|:---|
| **ReadWriteOnce** (RWO) | 한 노드에서 읽기·쓰기 |
| **ReadOnlyMany** (ROX) | 여러 노드에서 읽기 전용 |
| **ReadWriteMany** (RWX) | 여러 노드에서 읽기·쓰기 |
| **ReadWriteOncePod** (RWOP) | 한 Pod에서만 읽기·쓰기 |

---

## 실습 2: PVC로 영속 볼륨

minikube에는 기본 StorageClass(`standard`)가 있어 PVC만 만들면 PV가 자동 생성된다.

```bash
kubectl get storageclass      # standard (default) 확인
```

`pvc-pod.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi          # storageClassName 생략 → 기본 클래스 사용
---
apiVersion: v1
kind: Pod
metadata:
  name: pvc-app
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["/bin/sh", "-c", "echo persisted > /data/out; sleep 3600"]
      volumeMounts:
        - name: storage
          mountPath: /data
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: my-pvc
```

```bash
kubectl apply -f pvc-pod.yaml
kubectl get pvc my-pvc        # STATUS Bound 확인 (PV 자동 생성됨)
kubectl exec pvc-app -- cat /data/out   # → persisted

kubectl delete -f pvc-pod.yaml
kubectl delete pvc my-pvc     # PVC를 지워야 PV도 정리됨
```

---

## 참고 링크

- Volumes: <https://kubernetes.io/ko/docs/concepts/storage/volumes/>
- Persistent Volumes: <https://kubernetes.io/ko/docs/concepts/storage/persistent-volumes/>
