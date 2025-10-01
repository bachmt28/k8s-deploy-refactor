{{/*
workload.chartLabel:
  - Tên "ngắn" của app/chart dùng cho app.kubernetes.io/name
  - Ưu tiên Values.chartLabel, fallback .Chart.Name
*/}}
{{- define "workload.chartLabel" -}}
{{- default .Chart.Name .Values.chartLabel | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
workload.fullname:
  - Nếu có fullnameOverride: dùng override (chuẩn DNS-1123)
  - Mặc định: dùng .Release.Name (đã build đủ org-site-env-system-chartlabel từ CI)
*/}}
{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride -}}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
workload.name:
  - Tên rút gọn (thường cho metadata.name của ServiceAccount v.v.)
  - Ở đây vẫn dùng chartLabel để đồng nhất vai trò "app name"
*/}}
{{- define "workload.name" -}}
{{- include "workload.chartLabel" . -}}
{{- end -}}

{{/*
workload.commonLabels:
  - Bộ nhãn chuẩn, dùng ở metadata.labels của mọi tài nguyên
  - Lưu ý: selector phải dùng "selectorLabels" để tránh drift
*/}}
{{- define "workload.commonLabels" -}}
app.kubernetes.io/name: {{ include "workload.chartLabel" . }}
app.kubernetes.io/instance: {{ include "workload.fullname" . }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/version: {{ default .Chart.AppVersion .Values.appVersion | quote }}
app.kubernetes.io/part-of: {{ default .Values.system .Values.appGroup | default "core" }}
org: {{ .Values.org | default "default" }}
env: {{ .Values.env | default "dev" }}
site: {{ .Values.site | default "dc" }}
system: {{ .Values.system | default "sys" }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels | nindent 0 }}
{{- end }}
{{- end -}}

{{/*
workload.selectorLabels:
  - Chỉ gồm các key dùng để match (AND)
  - Dùng chung cho Deployment/StatefulSet/Service/PDB/NetworkPolicy...
*/}}
{{- define "workload.selectorLabels" -}}
app.kubernetes.io/name: {{ include "workload.chartLabel" . }}
app.kubernetes.io/instance: {{ include "workload.fullname" . }}
{{- end -}}

{{/*
workload.podLabels:
  - Nhãn cho Pod template; ghép thêm custom (Values.podLabels)
*/}}
{{- define "workload.podLabels" -}}
{{ include "workload.selectorLabels" . }}
{{- if .Values.podLabels }}
{{ toYaml .Values.podLabels | nindent 0 }}
{{- end }}
{{- end -}}

{{/*
workload.commonAnnotations:
  - Annotation chung cấp tài nguyên (metadata.annotations)
*/}}
{{- define "workload.commonAnnotations" -}}
{{- if .Values.commonAnnotations -}}
{{ toYaml .Values.commonAnnotations | nindent 0 }}
{{- end -}}
{{- end -}}

{{/*
workload.podAnnotations:
  - Annotation cho Pod template
*/}}
{{- define "workload.podAnnotations" -}}
{{- if .Values.podAnnotations -}}
{{ toYaml .Values.podAnnotations | nindent 0 }}
{{- end -}}
{{- end -}}

{{/*
Các helper đặt tên tài nguyên:
  - Tất cả build từ fullname để tuyệt đối đồng bộ với selector/envFrom/ref
*/}}
{{- define "workload.cmEnvName" -}}
{{- printf "%s-env" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.cmFileName" -}}
{{- printf "%s-file" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.secretName" -}}
{{- printf "%s-secret" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.svcName" -}}
{{- printf "%s-svc" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.headlessSvcName" -}}
{{- printf "%s-hl" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.saName" -}}
{{- printf "%s-sa" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.pdbName" -}}
{{- printf "%s-pdb" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.hpaName" -}}
{{- printf "%s-hpa" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "workload.ingressName" -}}
{{- printf "%s-ing" (include "workload.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
workload.imagePullSecrets:
  - Render list imagePullSecrets nếu có
*/}}
{{- define "workload.imagePullSecrets" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
{{- range . }}
  - name: {{ . | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
workload.dnsConfig:
  - Optional dnsConfig cho Pod
*/}}
{{- define "workload.dnsConfig" -}}
{{- with .Values.dnsConfig }}
dnsConfig:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
workload.affinity / tolerations / nodeSelector:
  - Optional scheduling fields
*/}}
{{- define "workload.nodeSelector" -}}
{{- with .Values.nodeSelector }}
nodeSelector:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "workload.tolerations" -}}
{{- with .Values.tolerations }}
tolerations:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "workload.affinity" -}}
{{- with .Values.affinity }}
affinity:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
