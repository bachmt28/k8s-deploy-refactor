{{/* =========================
   Sanitize (lowercase, dash, strip)
   ========================= */}}
{{- define "workload._sanitize" -}}
{{- . | toString | lower | replace "_" "-" | regexReplaceAll "[^a-z0-9-]" "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/* =========================
   Image helpers
   ========================= */}}
{{- define "workload.image.name" -}}
{{- if .Values.workload.specs.image.name -}}
  {{- include "workload._sanitize" .Values.workload.specs.image.name -}}
{{- else -}}
  {{- include "workload.chartLabel" . -}}
{{- end -}}
{{- end -}}

{{- define "workload.image.repository" -}}
{{- required "workload.specsimage.repository is required" .Values.workload.specs.image.repository -}}
{{- end -}}

{{- define "workload.image.tag" -}}
{{- default (default "latest" .Chart.AppVersion) .Values.workload.specs.image.tag -}}
{{- end -}}

{{- define "workload.image.pullPolicy" -}}
{{- default "IfNotPresent" .Values.workload.specs.image.pullPolicy -}}
{{- end -}}

{{/* ============ Names ============ */}}

{{/* chartLabel: lấy y nguyên từ values */}}
{{- define "workload.chartLabel" -}}
{{- .Values.chartLabel -}}
{{- end -}}

{{/* name: org-site-env-system-chartLabel-(release nếu có) */}}
{{- define "workload.name" -}}
{{- if .Values.nameOverride -}}
  {{- .Values.nameOverride -}}
{{- else -}}
  {{- $parts := list -}}
  {{- if .Values.org    }}{{- $parts = append $parts .Values.org    }}{{- end -}}
  {{- if .Values.site   }}{{- $parts = append $parts .Values.site   }}{{- end -}}
  {{- if .Values.env    }}{{- $parts = append $parts .Values.env    }}{{- end -}}
  {{- if .Values.system }}{{- $parts = append $parts .Values.system }}{{- end -}}
  {{- $parts = append $parts (include "workload.chartLabel" .) -}}
  {{- if .Release.Name  }}{{- $parts = append $parts .Release.Name  }}{{- end -}}
  {{- join "-" $parts -}}
{{- end -}}
{{- end -}}

{{/* fullname: y hệt name, trừ khi override */}}
{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride -}}
  {{- .Values.fullnameOverride -}}
{{- else -}}
  {{- include "workload.name" . -}}
{{- end -}}
{{- end -}}




{{/* =========================
   Labels: app & version
   ========================= */}}
{{- define "workload.appLabel" -}}
{{- include "workload.fullname" . -}}
{{- end -}}

{{- define "workload.version" -}}       {{/* Istio routing subset preferred */}}
{{- if .Values.routingVersion -}}
  {{- include "workload._sanitize" .Values.routingVersion -}}
{{- else -}}
  {{- include "workload.image.tag" . -}}
{{- end -}}
{{- end -}}

{{/* =========================
   Chart/standard labels
   ========================= */}}
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "workload.labels" -}}        {{/* Gắn lên Pod/Service/etc. (không dùng cho selector) */}}
helm.sh/chart: {{ include "workload.chart" . }}
app.kubernetes.io/name: {{ include "workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ include "workload.image.tag" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ include "workload.appLabel" . }}
version: {{ include "workload.version" . }}
{{- end -}}

{{- define "workload.extraPodLabels" -}}
{{- with .Values.workload.extraPodLabels }}
{{ toYaml . }}
{{- end -}}
{{- end -}}

{{/* =========================
   Selector labels (ổn định)
   ========================= */}}
{{- define "workload.selectorLabels" -}}
app: {{ include "workload.appLabel" . }}
{{- end -}}

{{- define "workload.matchLabels" -}}
{{ include "workload.selectorLabels" . }}
{{- end -}}

{{/* =========================
   Resource names
   ========================= */}}
{{- define "workload.serviceName" -}}
{{- default (include "workload.fullname" .) .Values.service.name -}}
{{- end -}}

{{- define "workload.configMapName" -}}
{{- default (printf "%s-config" (include "workload.fullname" .)) .Values.configMap.name -}}
{{- end -}}

{{- define "workload.secretName" -}}
{{- default (printf "%s-secret" (include "workload.fullname" .)) .Values.secrets.name -}}
{{- end -}}

{{/* =========================
   Kind normalize
   ========================= */}}
{{- define "workload.workloadKind" -}}
{{- $k := default "Deployment" .Values.workload.kind | toString | lower -}}
{{- if eq $k "statefulset" -}}StatefulSet{{- else -}}Deployment{{- end -}}
{{- end -}}

{{/* =========================
     Checksums for rollout
     - Hash nội dung render của configmap.yaml / secret.yaml
     - Nếu disabled => trả chuỗi rỗng (không thêm annotation)
     ========================= */}}

{{- define "workload.configChecksum" -}}
{{- if .Values.configMap.enabled -}}
{{- include (print .Template.BasePath "/configmap.yaml") . | sha256sum -}}
{{- else -}}{{- "" -}}{{- end -}}
{{- end -}}

{{- define "workload.secretChecksum" -}}
{{- if .Values.secrets.enabled -}}
{{- include (print .Template.BasePath "/secret.yaml") . | sha256sum -}}
{{- else -}}{{- "" -}}{{- end -}}
{{- end -}}

{{/* Headless service name (allow override) */}}
{{- define "workload.headlessServiceName" -}}
{{- default (printf "%s-headless" (include "workload.fullname" .)) .Values.service.headlessName -}}
{{- end -}}

{{- define "workload.serviceEnabled" -}}
{{- $enabled := true -}}
{{- if and (hasKey .Values "service") (hasKey .Values.service "enabled") -}}
  {{- $enabled = .Values.service.enabled -}}
{{- end -}}
{{- if $enabled -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "workload.headlessEnabled" -}}
{{- $isStateful := eq (include "workload.workloadKind" .) "StatefulSet" -}}
{{- $enabled := and $isStateful true -}}
{{- if and $isStateful (hasKey .Values "service") (hasKey .Values.service "headlessEnabled") -}}
  {{- $enabled = .Values.service.headlessEnabled -}}
{{- end -}}
{{- if $enabled -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/* Which serviceName should StatefulSet use? */}}
{{- define "workload.statefulServiceName" -}}
{{- if eq (include "workload.headlessEnabled" .) "true" -}}
  {{- include "workload.headlessServiceName" . -}}
{{- else -}}
  {{- include "workload.serviceName" . -}}
{{- end -}}
{{- end -}}

{{/* =========================
   Safe ServiceAccount name resolver
   - Nếu user set serviceAccount.name -> dùng nó
   - Nếu create=true và name rỗng     -> dùng fullname (vì sẽ tạo mới)
   - Nếu create=false và name rỗng    -> dùng "default" (tránh trỏ vào SA không tồn tại)
   ========================= */}}
{{- define "workload.serviceAccountNameSafe" -}}
{{- if .Values.serviceAccount.name -}}
  {{- .Values.serviceAccount.name -}}
{{- else -}}
  {{- if .Values.serviceAccount.create -}}
    {{- include "workload.fullname" . -}}
  {{- else -}}
    default
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* =========================
   ServiceAccount automount toggle (default=true, respect false)
   ========================= */}}
{{- define "workload.serviceAccountAutomount" -}}
{{- if hasKey .Values.serviceAccount "automount" -}}
{{ .Values.serviceAccount.automount }}
{{- else -}}
true
{{- end -}}
{{- end -}}
