# Helm Chart Review

## 1. ConfigMap volume không khớp tên thực tế (blocker)
**Issue**: Giá trị mặc định đang mount một `ConfigMap` có `name: ""` trong Pod spec (`workload.volumes[0]`), trong khi template `configmap.yaml` lại sinh ra tài nguyên với tên `<fullname>-config`. Khi giữ nguyên values mặc định, Kubernetes sẽ từ chối manifest do thiếu tên ConfigMap hợp lệ.

**Minh hoạ**:
```yaml
# charts/values.yaml
workload:
  volumes:
    - name: cfg
      configMap: { name: "", optional: true }
```
Sinh ra trong `templates/workload.yaml`:
```yaml
volumes:
  - name: cfg
    configMap:
      name: ""
      optional: true
```
=> lỗi `spec.template.spec.volumes[0].configMap.name: Required value`.

**Đề xuất**: Tự động nối tên bằng helper sẵn có (ví dụ `{{ include "workload.configMapName" . }}`) khi `configMap.name` trống, hoặc đơn giản hơn là đổi giá trị mặc định trong `values.yaml` thành `name: {{ include "workload.configMapName" . }}` bằng cơ chế `tpl`. Logic: Pod luôn mount đúng ConfigMap mà chart render, tránh cấu hình sai mặc định.

## 2. HPA mặc định thiếu metric bắt buộc (critical)
**Issue**: `hpa.enabled=true` nhưng `hpa.metrics` mặc định rỗng. Với `apiVersion: autoscaling/v2`, Kubernetes yêu cầu tối thiểu một metric, nếu không sẽ trả về lỗi `spec.metrics: Required value`.

**Minh hoạ**:
```yaml
# charts/templates/hpa.yaml
spec:
  minReplicas: 1
  maxReplicas: 3
  # metrics: <bỏ trống>
```
Triển khai với values mặc định sẽ fail.

**Đề xuất**: Hoặc cung cấp metric mặc định (ví dụ CPU utilisation) trong `values.yaml`, hoặc đổi mặc định `hpa.enabled=false` để người dùng chủ động cấu hình metric trước khi bật. Logic: đảm bảo manifest hợp lệ ngay từ mặc định, tránh pipeline Helm/GitOps gãy giữa chừng.

