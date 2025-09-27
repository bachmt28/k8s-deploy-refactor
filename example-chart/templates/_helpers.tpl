{{/* =========================
   Naming helpers
   ========================= */}}

{{/* chartLabel: bắt buộc, lấy nguyên xi từ values */}}
{{- define "workload.chartLabel" -}}
{{- .Values.chartLabel -}}
{{- end -}}

{{/* fullname:
     - Nếu có fullnameOverride: dùng override
     - Mặc định: .Release.Name + "-" + chartLabel
*/}}
{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride -}}
  {{- .Values.fullnameOverride -}}
{{- else -}}
  {{- printf "%s-%s" .Release.Name (include "workload.chartLabel" .) -}}
{{- end -}}
{{- end -}}

{{/* selectorLabels: dùng cho matchLabels Pod selector */}}
{{- define "workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "workload.chartLabel" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* commonLabels: dán lên mọi tài nguyên (Deployment/STS/Service/etc.)
   - Chỉ dùng org/env/site/system cho labels/annotations, không tham gia đặt tên
*/}}
{{- define "workload.commonLabels" -}}
app.kubernetes.io/name: {{ include "workload.chartLabel" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- if .Values.system }}
app.kubernetes.io/part-of: {{ .Values.system }}
{{- end }}
{{- if .Values.org }}org: {{ .Values.org }}{{- end }}
{{- if .Values.env }}env: {{ .Values.env }}{{- end }}
{{- if .Values.site }}site: {{ .Values.site }}{{- end }}
{{- if .Values.system }}system: {{ .Values.system }}{{- end }}
{{- /* optional global labels */ -}}
{{- range $k, $v := .Values.commonLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{/* commonAnnotations: áp lên tài nguyên nếu có */}}
{{- define "workload.commonAnnotations" -}}
{{- range $k, $v := .Values.commonAnnotations }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{/* =========================
   Default names for related resources
   ========================= */}}

{{/* Service name (thường) */}}
{{- define "workload.serviceName" -}}
{{- if .Values.service.name -}}
  {{- .Values.service.name -}}
{{- else -}}
  {{- include "workload.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Headless Service name (STS) */}}
{{- define "workload.headlessName" -}}
{{- if .Values.service.headlessName -}}
  {{- .Values.service.headlessName -}}
{{- else -}}
  {{- printf "%s-headless" (include "workload.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* ConfigMap name */}}
{{- define "workload.configMapName" -}}
{{- if .Values.configMap.name -}}
  {{- .Values.configMap.name -}}
{{- else -}}
  {{- printf "%s-config" (include "workload.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Secret name */}}
{{- define "workload.secretName" -}}
{{- if .Values.secrets.name -}}
  {{- .Values.secrets.name -}}
{{- else -}}
  {{- printf "%s-secret" (include "workload.fullname" .) -}}
{{- end -}}
{{- end -}}
