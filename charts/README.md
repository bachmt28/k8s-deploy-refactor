
---

# Helm Chart – Hướng dẫn sử dụng (refactor)

## 1) Yêu cầu

* Helm ≥ 3.8
* Kubernetes ≥ 1.21
* Nếu image private: đã có `imagePullSecret`

## 2) Cấu trúc chart

```
charts/
  Chart.yaml
  values.yaml
  templates/
    _helpers.tpl
    workload.yaml            # Deployment/StatefulSet (auto theo workload.kind)
    service.yaml             # Service + headless (nếu STS & bật)
    configmap.yaml
    secret.yaml
    serviceaccount.yaml
    hpa.yaml
    pdb.yaml
    # (optional) ingress/istio/rbac/tests...
```

## 3) Giá trị chính trong `values.yaml`

```yaml
# ===== IDENT / LABEL =====
org: []       # optional sb|ptf|asean
env: []       # optional live|pilot|uat
site: []      # optional khi stateful nhiều site
system: []    # optional
mainLabel: example-workload
# nameOverride: ""         # không cần
fullnameOverride: ""       # để trống -> auto ghép org-site-env-system-mainLabel

# ===== WORKLOAD =====
workload:
  kind: Deployment         # hoặc StatefulSet
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 25%, maxUnavailable: 0 }
  terminationGracePeriodSeconds: 30
  extraPodLabels: {}
  podAnnotations: {}
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  podSecurityContext: { runAsNonRoot: true, fsGroup: 2000 }
  priorityClassName: ""
  dnsConfig: {}
  hostAliases: []
  imagePullSecrets: []     # [{ name: nexus-repo-secret }]

  volumes:
    - name: cfg
      configMap: { name: "", optional: true }
    - name: tmp
      emptyDir: {}

  main:
    image:
      repository: nexus-img.seabank.com.vn
      # name: ""            # để trống -> mặc định = mainLabel
      tag: "1.0.0"
      pullPolicy: IfNotPresent
    command: []
    args: []
    env:
      - { name: TZ, value: Asia/Ho_Chi_Minh }
      - { name: SPRING_PROFILES_INCLUDE, value: fwbase }
    envFrom: []
    ports:
      - { name: http, containerPort: 8081, protocol: TCP }
    resources:
      requests: { cpu: "1", memory: 1Gi }
      limits:   { cpu: "2", memory: 2Gi }
    volumeMounts:
      - { name: cfg, mountPath: /opt/config }
      - { name: tmp, mountPath: /tmp }
    # readinessProbe/livenessProbe/startupProbe có thể bật khi cần
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities: { drop: ["ALL"] }

  initContainers: []
  sidecars: []

# ===== SERVICE =====
service:
  enabled: true
  headlessEnabled: true     # dùng cho StatefulSet
  name: ""                  # mặc định = fullname
  type: ClusterIP
  annotations: {}
  ports:
    - { name: http, port: 8081, targetPort: 8081 }

# ===== CONFIGMAP / SECRET =====
configMap: { enabled: true, name: "", data: {} }
secrets:   { enabled: true, name: "", autoMount: true, stringData: {} }

# ===== SA / HPA / PDB =====
serviceAccount: { create: true, name: "", annotations: {}, automount: true }
hpa: { enabled: true, minReplicas: 1, maxReplicas: 3, metrics: [], behavior: {} }
pdb: { enabled: true, minAvailable: 1 }

# (optional) nếu dùng Istio
# routingVersion: live     # nếu set -> labels.version = this; nếu không -> fallback image.tag
```

### Cách chart đặt tên & nhãn (quan trọng)

* **fullname** = `org-site-env-system-mainLabel` *(bỏ phần trống)*
* **app label (selector)** = `fullname`
* **version label** = `routingVersion` *(nếu có)*, **fallback** `image.tag`
* **Service selector chỉ dùng `app`** (ổn định) → đổi `version` để route Istio **không** làm vỡ selector.

### Rollout khi ConfigMap/Secret đổi

Chart đã gắn **`checksum/config`** & **`checksum/secret`** lên Pod Template → đổi `configMap.data`/`secrets.stringData` sẽ **tự rolling**.

---

## 4) Cài đặt nhanh

### Cài mới

```bash
helm install t24-api ./charts \
  --set org=sb,site=hcm,env=uat,system=t24,mainLabel=los-clos-api \
  --set workload.main.image.repository=nexus-img.seabank.com.vn \
  --set workload.main.image.tag=1.0.0
```

### Nâng cấp ảnh (rolling update)

```bash
helm upgrade --install t24-api ./charts \
  --set workload.main.image.tag=1.1.0
```

### Xem manifest trước khi cài

```bash
helm template t24-api ./charts -f values.yaml
```

### Gỡ

```bash
helm uninstall t24-api
```

---

## 5) Chạy StatefulSet

```bash
helm upgrade --install t24-api ./charts \
  --set workload.kind=StatefulSet
```

* `service.headlessEnabled: true` sẽ tạo thêm `headless Service` (`<fullname>-headless`) cho DNS ổn định.
* Nếu app cần PVC per-pod, bổ sung `stateful.volumeClaimTemplates` trong values (phần optional bạn có thể thêm sau).

---

## 6) Probes & Autoscaling (khuyến nghị)

```yaml
workload:
  main:
    readinessProbe:
      httpGet: { path: /actuator/health/readiness, port: 8081 }
      initialDelaySeconds: 10
      periodSeconds: 5

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

## 7) ConfigMap & Secret

```yaml
configMap:
  enabled: true
  data:
    application.yml: |-
      spring:
        profiles.active: uat

secrets:
  enabled: true
  stringData:
    SPRING_DATASOURCE_URL: jdbc:postgresql://example:5432/db
    SPRING_DATASOURCE_USERNAME: user
    SPRING_DATASOURCE_PASSWORD: pass
```

> Đổi nội dung 2 thằng này → Pod tự rollout nhờ **checksum annotations**.

---

## 8) Istio routing (nếu dùng)

* Pod sẽ có nhãn:

  * `app: <fullname>`
  * `version: <routingVersion | image.tag>`
* DestinationRule subset cần khớp `labels.version`.
  Ví dụ:

```yaml
routingVersion: live   # release chính
# release pilot:
# routingVersion: pilot
```

VirtualService route theo trọng số subset `live/pilot`.

---

## 9) Nhiều phiên bản song song (live/pilot)

**Mỗi phiên bản = 1 Helm release**:

```bash
# live
helm upgrade --install t24-api-live ./charts \
  --set routingVersion=live \
  --set workload.main.image.tag=1.2.0
# pilot
helm upgrade --install t24-api-pilot ./charts \
  --set routingVersion=pilot \
  --set workload.main.image.tag=1.3.0 \
  --set service.enabled=false   # nếu muốn dùng chung Service của live
```

---

## 10) Debug nhanh

```bash
# Xem các Pod theo app label
kubectl get pods -l app=$(helm template t ./charts | yq '.items[] | select(.kind=="Deployment" or .kind=="StatefulSet") | .metadata.labels.app' -r)

# Logs container chính
kubectl logs deploy/$(helm template t ./charts | yq '.items[] | select(.kind=="Deployment") | .metadata.name' -r) -c $(helm template t ./charts | yq '.items[] | select(.kind=="Pod") | .spec.containers[0].name' -r | head -n1)

# Kiểm tra rollout khi đổi config/secret
kubectl describe deploy/<fullname> | grep -A2 "checksum/"
```

---

## 11) Tips vận hành

* **Không** dùng `version` trong selector; chỉ dùng `app`.
* `mainLabel` là “hạt nhân” → suy ra `image.name`, `container name` & `fullname`.
* Đặt `Release.Name` rõ ràng (ví dụ `t24-api-live`, `t24-api-pilot`) để dễ tra cứu lịch sử & rollback.
* Khi xài Jenkins/GitOps, nhớ **tag ảnh bất biến** (`1.2.3`, `sha`) — đừng xài `latest`.

## 12) Kiểm tra nhanh Service toggles

Một số lệnh `helm template` giúp xác nhận behaviour mới:

```bash
# Tắt Service chính, chỉ render workload (Deployment)
helm template demo ./charts --set service.enabled=false

# StatefulSet vẫn render Service thường khi headless bị tắt
helm template demo ./charts \
  --set workload.kind=StatefulSet \
  --set service.headlessEnabled=false

# Khi đồng thời tắt cả hai Service cho StatefulSet sẽ báo lỗi
helm template demo ./charts \
  --set workload.kind=StatefulSet \
  --set service.enabled=false \
  --set service.headlessEnabled=false
```

Lệnh cuối phải trả về lỗi `Invalid config: StatefulSet requires either service.headlessEnabled=true or service.enabled=true...` để
chứng minh guard chống cấu hình sai đang hoạt động.


