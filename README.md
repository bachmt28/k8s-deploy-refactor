
# Hướng dẫn sử dụng Helm chart

## 1) Tổng quan

* Chart sinh **workload K8s** (Deployment hoặc StatefulSet) + Service (thường & headless), ConfigMap/Secret, HPA, PDB, PVC, ServiceAccount.
* **Selector labels** dùng chuẩn CNCF:

  * `app.kubernetes.io/name` = tên ứng dụng logic (lấy từ `chartLabel`)
  * `app.kubernetes.io/instance` = tên instance (fullname)
* **Version** dán vào `app.kubernetes.io/version` theo quy tắc:
  `Values.version` (nếu có) → **fallback** `workload.specs.image.tag`.

## 2) Cấu trúc chart (rút gọn)

```
charts/
  example-workload/
    Chart.yaml
    values.yaml
    templates/
      _helpers.tpl            # helper chuẩn hóa tên, labels, version, checksums
      deployment.yaml         # render khi kind=Deployment
      statefulset.yaml        # render khi kind=StatefulSet
      service.yaml            # Service thường (Deployment)
      service-headless.yaml   # Headless Service (StatefulSet)
      configmap-*.yaml        # CM env/file
      secret-*.yaml           # Secret env/list
      serviceaccount.yaml
      hpa.yaml
      pdb.yaml
      pvc.yaml
```

## 3) Quy tắc đặt tên (fullname)

* Mặc định:

  * Nếu `.Release.Name` **là mặc định** của Helm (`release-name`/`RELEASE-NAME`) ⇒ fullname = **`env-chartLabel`**.
  * Nếu CI/Jenkins set `.Release.Name` (ví dụ `org-site-env-system-chartLabel`) ⇒ **tôn trọng nguyên xi**.
* Có sanitize (lowercase, thay ký tự lạ bằng `-`, gộp `-`, bỏ token rỗng/trùng kề, cắt 63 ký tự).
* Có thể **override**:

  * `workload.fullname` **hoặc** `fullnameOverride` trong values.

## 4) Labels & Annotations

* **Selector** (luôn có, dùng để match):

  ```
  app.kubernetes.io/name: <chartLabel>
  app.kubernetes.io/instance: <fullname>
  ```
* **Standard labels** (metadata):

  ```
  app.kubernetes.io/version: <Values.version || image.tag>
  app.kubernetes.io/managed-by: Helm
  helm.sh/chart: <chart-version>
  ```
* **Context labels** (tùy chọn, có prefix):
  Set trong values:

  ```yaml
  org: "sb"
  site: ""
  env: "live"
  system: ""
  labeling:
    prefix: "context.platform.io/"   # phải kết thúc bằng '/'
  ```

  → Render (chỉ các key có giá trị):

  ```
  context.platform.io/org: "sb"
  context.platform.io/env: "live"
  ...
  ```

## 5) Workload (Deployment/StatefulSet)

* `workload.kind`: `Deployment` hoặc `StatefulSet`.
* `replicas`, `revisionHistoryLimit`, `strategy` (Deployment), `statefulSetUpdateStrategy` (StatefulSet).
* Pod spec:

  * `podLabels`, `podAnnotations` (không ảnh hưởng selector).
  * `nodeSelector`, `tolerations`, `affinity`, `topologySpreadConstraints`.
  * `podSecurityContext`, `priorityClassName`, `dnsConfig`, `hostAliases`.
  * `automountServiceAccountToken: false` (an toàn mặc định, bật lên khi thực sự cần).
  * `volumes`, `initContainers`, `sidecars`.

### Container chính (`workload.specs`)

* Image:

  ```yaml
  image:
    repository: nexus-img.seabank.com.vn
    name: ""         # rỗng => mặc định = chartLabel
    tag: 1.0.0
    pullPolicy: IfNotPresent
  ```

  → Chuỗi image được ghép: `<repository>/<name>:<tag>` (hoặc `<name>:<tag>` nếu repository rỗng).
* `command`, `args`, `ports`, `resources`, `volumeMounts`, `securityContext`.
* Probes:

  * Nếu để `{}` → **không render** probe đó (tránh sinh field rỗng).
* Env:

  * `env`: mảng các cặp name/value (tránh trùng `name`).
  * `envFrom` (do user khai báo thủ công) **ưu tiên**.
  * Tự động `envFrom` thêm từ CM/Secret nếu bật `autoMount` (mục ConfigMap/Secret).

## 6) Service

* `service.enabled: true`, `type: ClusterIP`.
* `service.name`: rỗng → mặc định = `<fullname>`.
* `service.ports`: đảm bảo `targetPort` khớp `containerPort`.
* **Headless**:

  * Chỉ render khi `kind=StatefulSet` **và** `service.headlessEnabled=true`.
  * `headlessName`: rỗng → `<fullname>-headless`.

## 7) ConfigMap & Secret

* `configMap.env`:

  * `enabled: true` → tạo CM chứa key/value cho envFrom.
  * `name`: rỗng → `<fullname>-env`.
  * `autoMount: true` → nếu user **không** tự khai `workload.specs.envFrom`, chart sẽ tự gắn `envFrom` vào container.
* `configMap.file`:

  * `enabled: true` → tạo CM chứa file (multi-line OK).
* `secrets.env`:

  * Secret cho envFrom, `autoMount: true` (giống CM).
* `secrets.list[]`:

  * Tạo nhiều Secret rời, **không autoMount** (dùng khi cần, tự tham chiếu ở Pod).

### Auto-rollout khi CM/Secret đổi

* Pod template có **checksum annotations** dựa trên nội dung:

  * `configMap.env.data`, `configMap.file.data`
  * `secrets.env.stringData`, `secrets.list[*].stringData`
* Khi giá trị thay đổi → checksum đổi → Pod tự **rollout**.

> Lưu ý: Nếu dùng ExternalSecrets/operator khác, checksum ở đây **không** theo dõi CRD đó.

## 8) PVC

* `pvc.enabled: true`:

  * Nếu **có** `claimName` → **không** tạo PVC, pod dùng claim sẵn có.
  * Nếu **không** `claimName` → chart tạo PVC mới:

    * `storageClassName`, `accessModes`, `persistentVolumeClaim.requests.storage`.
* Gắn vào Pod bằng `workload.volumes` + `workload.specs.volumeMounts`.

## 9) ServiceAccount

* `serviceAccount.create: true`:

  * `name`: rỗng → `<fullname>`.
* Nếu `create: false` → dùng `default` hoặc tên chỉ định.

## 10) HPA

* `hpa.enabled: true` → tạo HPA (`autoscaling/v2` nếu cluster hỗ trợ).
* `minReplicas`, `maxReplicas`, `metrics` (cpu/memory…), `behavior` (scaleUp/Down).
* `scaleTargetRef.kind` tự set theo `workload.kind`.

## 11) PDB

* `pdb.enabled: true`, `minAvailable: 1`.
* Selector dựa trên selector labels (name + instance).

## 12) Validate (khuyến nghị)

* (Tùy chọn) Thêm `values.schema.json` ở **root chart** để validate values khi `helm lint/install`.
* `$schema` có thể giữ/bỏ; Helm **không** cần Internet để dùng file này.

## 13) Lệnh thao tác nhanh

### Lint & template

```bash
helm lint charts/example-workload
helm template charts/example-workload \
  --set chartLabel=example \
  --set env=live
```

### Cài đặt local (mặc định fullname = env-chartLabel)

```bash
helm install example charts/example-workload \
  --set chartLabel=example \
  --set env=live
# Kết quả fullname: live-example
```

### Cài đặt theo CI đặt sẵn Release.Name

```bash
helm install sb-ptf-live-core-example charts/example-workload \
  --set chartLabel=example \
  --set env=live
# Kết quả fullname: sb-ptf-live-core-example (tôn trọng .Release.Name)
```

### Override fullname

```bash
helm install x charts/example-workload \
  --set workload.fullname=custom-x \
  --set chartLabel=example --set env=live
# fullname = custom-x
```

### StatefulSet + headless

```bash
helm template charts/example-workload \
  --set chartLabel=example \
  --set env=live \
  --set workload.kind=StatefulSet \
  --set service.headlessEnabled=true
```

## 14) Ví dụ cấu hình

### (A) Tối thiểu – Deployment + Service

```yaml
chartLabel: example
env: live
labeling:
  prefix: "context.platform.io/"

workload:
  kind: Deployment
  replicas: 2
  specs:
    image:
      repository: nexus-img.seabank.com.vn
      tag: 1.0.0
    ports:
      - name: http
        containerPort: 8081

service:
  enabled: true
  ports:
    - name: http
      port: 8081
      targetPort: 8081
```

### (B) StatefulSet + Headless + PVC

```yaml
chartLabel: example
env: live
site: hcm
labeling:
  prefix: "context.platform.io/"

workload:
  kind: StatefulSet
  replicas: 3
  specs:
    image:
      repository: nexus-img.seabank.com.vn
      tag: 1.0.0
    volumeMounts:
      - name: data
        mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ""  # để trống nếu chart tự tạo PVC

service:
  headlessEnabled: true

pvc:
  enabled: true
  storageClassName: standard-rwo
  accessModes: [ReadWriteOnce]
  persistentVolumeClaim:
    requests:
      storage: 20Gi
```

### (C) Version override (khác tag)

```yaml
version: "2.3.4"
workload:
  specs:
    image:
      repository: nexus-img.seabank.com.vn
      tag: 1.0.0
```

→ Label `app.kubernetes.io/version: "2.3.4"`

### (D) AutoMount envFrom từ CM/Secret

```yaml
configMap:
  env:
    enabled: true
    autoMount: true
    data:
      LOG_LEVEL: info

secrets:
  env:
    enabled: true
    autoMount: true
    stringData:
      DB_PASSWORD: "s3cr3t"
```

## 15) Truy vấn & vận hành

* Tìm theo app:

  ```
  kubectl get pods -l app.kubernetes.io/name=example
  ```
* Tìm theo instance:

  ```
  kubectl get deploy -l app.kubernetes.io/instance=live-example
  ```
* Tìm theo context:

  ```
  kubectl get pods -l context.platform.io/env=live
  kubectl get pods -l context.platform.io/org=sb
  ```

## 16) Lưu ý & lỗi thường gặp

* **Vẫn ra `release-name`** khi template ⇒ kiểm tra helper đã vá logic fallback chưa; phải rơi về `env-chartLabel` nếu `.Release.Name` là default.
* **StatefulSet thiếu `site`**: bản thân label `site` là chỉ dẫn (labels only). Nếu policy nội bộ yêu cầu, hãy thêm `site` khi `kind=StatefulSet`.
* **Prefix thiếu dấu “/”**: `labeling.prefix` phải kết thúc bằng `/` (ví dụ `context.platform.io/`).
* **Trùng `env`/`name`** gây `"live-live-example"`? Helper đã **dedupe token kề**; vẫn nên đặt `env`/`chartLabel` rõ ràng.
* **`envFrom` đôi chỗ**: nếu đã tự khai `workload.specs.envFrom`, hãy cân nhắc tắt `autoMount` để tránh trùng.
* **Probe rỗng**: `{}` ⇒ không render. Đặt giá trị hợp lệ nếu cần.
* **targetPort** phải trùng với `containerPort` (nếu dùng số).

---

Muốn thêm **`values.schema.json`** để ép kiểu/enum (ví dụ `workload.kind` chỉ nhận `Deployment|StatefulSet`, `labeling.prefix` phải kết thúc bằng `/`, `env` không rỗng), ta có thể bổ sung sau.
