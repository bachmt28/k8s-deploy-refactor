# Helm chart — Hướng dẫn sử dụng

## 1) Yêu cầu

* Helm ≥ 3.8
* Kubernetes ≥ 1.21
* (Nếu kéo image private) Đã tạo `imagePullSecret`

## 2) Cấu trúc chart (rút gọn)

```
charts/
  Chart.yaml
  values.yaml               # theo schema đã chốt
  templates/
    _helpers.tpl
    workload.yaml           # Deployment/StatefulSet (auto theo workload.kind)
    service.yaml            # Service + (headless cho StatefulSet nếu bật)
    configmap.yaml
    secret.yaml
    serviceaccount.yaml
    hpa.yaml
    pdb.yaml
```

## 3) Giá trị mặc định quan trọng (trích)

```yaml
env: prod
org: sb
system: t24

workload:
  kind: Deployment
  replicas: 2
  volumes:
    - name: cfg
      configMap: { name: "", optional: true }
    - name: tmp
      emptyDir: {}
  main:
    name: app
    image: { repository: nexus.example.com/example-workload, tag: "1.0.0", pullPolicy: IfNotPresent }
    ports: [ { name: http, containerPort: 8081 } ]
    volumeMounts:
      - { name: cfg, mountPath: /opt/config }
      - { name: tmp, mountPath: /tmp }
  initContainers: []
  sidecars: []

service:
  name: ""            # mặc định = fullname
  type: ClusterIP
  ports: [ { name: http, port: 8081, targetPort: 8081 } ]

configMap:
  enabled: true
  name: ""
  data: {}

secrets:
  enabled: true
  name: ""
  autoMount: true
  stringData: {}

serviceAccount:
  create: true
  name: ""
  automount: true

hpa:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  metrics: []
  behavior: {}

pdb:
  enabled: true
  minAvailable: 1
```

---

## 4) Cài đặt cơ bản

### 4.1 Cài mới

```bash
helm install example ./charts \
  --set workload.main.image.repository=nexus.example.com/example-workload \
  --set workload.main.image.tag=1.0.0
```

### 4.2 Xem manifest trước khi cài

```bash
helm template example ./charts -f values.yaml
```

### 4.3 Nâng cấp (hoặc cài nếu chưa có)

```bash
helm upgrade --install example ./charts \
  --set workload.main.image.tag=1.1.0
```

### 4.4 Gỡ

```bash
helm uninstall example
```

---

## 5) Chuyển qua StatefulSet

> Khi chạy stateful app (DB, queue, cache, app cần stable hostname…)

1. Bật StatefulSet:

```bash
helm upgrade --install example ./charts \
  --set workload.kind=StatefulSet
```

2. (Khuyến nghị) Bật headless service (nếu bạn muốn):

* Trong `service.yaml` đã mặc định `service.headlessEnabled=true` cho StatefulSet.
* Nếu cần tắt: `--set service.headlessEnabled=false`.

> Lưu ý: nếu app cần PVC per-pod, hãy mở rộng template để tạo `volumeClaimTemplates` (chart này đang để volumes thủ công — tuỳ use case mà thêm).

---

## 6) Volumes & mounts (chuẩn K8s)

* Khai **Pod volumes** ở: `workload.volumes`.
* Mount từng volume tại: `workload.main.volumeMounts`, `workload.initContainers[].volumeMounts`, `workload.sidecars[].volumeMounts`.

**Ví dụ: thêm Secret + PVC**

```yaml
workload:
  volumes:
    - name: app-secret
      secret: { secretName: my-secret }
    - name: data
      persistentVolumeClaim: { claimName: my-pvc }
  main:
    volumeMounts:
      - { name: app-secret, mountPath: /opt/secret, readOnly: true }
      - { name: data, mountPath: /data }
```

---

## 7) InitContainers & Sidecars

### 7.1 InitContainers

```yaml
workload:
  initContainers:
    - name: init-config
      image: { repository: busybox, tag: "1.36" }
      command: ["sh","-c"]
      args: ["cp /seed/* /opt/config/ || true"]
      volumeMounts:
        - { name: cfg, mountPath: /opt/config }
```

### 7.2 Sidecar metrics

```yaml
workload:
  sidecars:
    - name: metrics
      image: { repository: prom/node-exporter, tag: "v1.7.0" }
      ports: [ { name: metrics, containerPort: 9100 } ]
```

---

## 8) Probes (khuyến nghị bật)

```yaml
workload:
  main:
    livenessProbe:
      httpGet: { path: /actuator/health/liveness, port: 8081 }
      initialDelaySeconds: 20
    readinessProbe:
      httpGet: { path: /actuator/health/readiness, port: 8081 }
      initialDelaySeconds: 10
```

---

## 9) ConfigMap & Secret

### 9.1 ConfigMap nội tuyến

```yaml
configMap:
  enabled: true
  name: ""
  data:
    application.yml: |-
      spring:
        profiles.active: prod
```

### 9.2 Secret nội tuyến

```yaml
secrets:
  enabled: true
  stringData:
    SPRING_DATASOURCE_URL: jdbc:postgresql://example:5432/db
    SPRING_DATASOURCE_USERNAME: user
    SPRING_DATASOURCE_PASSWORD: pass
```

---

## 10) Service

### 10.1 ClusterIP mặc định

```yaml
service:
  type: ClusterIP
  ports:
    - { name: http, port: 8081, targetPort: 8081 }  # targetPort khớp containerPort
```

### 10.2 NodePort / LoadBalancer

```yaml
service:
  type: LoadBalancer
  annotations: {}
```

> Nếu bạn deploy nhiều phiên bản cùng lúc (live/pilot), khuyến nghị **mỗi phiên bản = một Helm release** để dễ quản lý. Release phụ có thể `--set service.enabled=false` nếu muốn chỉ tạo workload mà không đụng Service.

---

## 11) HPA (autoscaling)

Bật HPA theo CPU/memory:

```yaml
hpa:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource: { name: cpu,    target: { type: Utilization, averageUtilization: 80 } }
    - type: Resource
      resource: { name: memory, target: { type: Utilization, averageUtilization: 80 } }
```

---

## 12) PDB

```yaml
pdb:
  enabled: true
  minAvailable: 1
```

---

## 13) Mẹo override nhanh

### 13.1 Override từng khóa

```bash
helm upgrade --install example ./charts \
  --set env=uat \
  --set workload.main.image.tag=1.2.3 \
  --set service.type=LoadBalancer
```

### 13.2 Dùng file env-specific

Tạo `values-uat.yaml`:

```yaml
env: uat
workload:
  replicas: 1
  main:
    image: { tag: "1.2.3" }
service:
  type: ClusterIP
```

Chạy:

```bash
helm upgrade --install example ./charts -f values.yaml -f values-uat.yaml
```

---

## 14) Quy ước labels (đã dựng trong helpers)

* Selector: chỉ dùng `app: <fullname>` (ổn định).
* Pod labels: thêm `env`, `version` (theo image tag), `app.kubernetes.io/*`.
  → Đổi `env/version` **không** phá selector.

---

## 15) Rollback / Debug

* Lịch sử:

```bash
helm history example
```

* Rollback:

```bash
helm rollback example <REVISION>
```

* Render để debug:

```bash
helm template example ./charts -f values.yaml > out.yaml
```

* Kiểm tra pod:

```bash
kubectl get pods -l app=$(helm get values example -o yaml | yq .workload.fullname)   # hoặc app label theo fullname
kubectl describe deploy/<name>
kubectl logs deploy/<name> -c app
```

---
