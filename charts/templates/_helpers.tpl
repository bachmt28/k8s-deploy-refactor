{{/* ================================
   Name / Fullname / Chart
================================ */}}
{{- define "workload.name" -}}
{{- if .Values.nameOverride -}}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Chart.Name -}}
{{- end -}}
{{- end -}}

{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "workload.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/* ================================
   Version / Env
   - version ưu tiên image tag của main
================================ */}}
{{- define "workload.version" -}}
{{- if .Values.workload.main.image.tag -}}
{{- .Values.workload.main.image.tag -}}
{{- else -}}
{{- default "latest" .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{- define "workload.env" -}}
{{- $e := default "prod" .Values.env | lower -}}
{{- if not (has $e (list "prod" "uat" "pilot" "live" "dev" "stg" "qa")) -}}prod{{- else -}}{{$e}}{{- end -}}
{{- end -}}

{{/* ================================
   Image helpers (main)
================================ */}}
{{- define "workload.image.repository" -}}
{{- required "workload.main.image.repository is required" .Values.workload.main.image.repository -}}
{{- end -}}

{{- define "workload.image.tag" -}}
{{- include "workload.version" . -}}
{{- end -}}

{{- define "workload.image.pullPolicy" -}}
{{- default "IfNotPresent" .Values.workload.main.image.pullPolicy -}}
{{- end -}}

{{/* ================================
   App label (ổn định cho selector)
   - mặc định = fullname, DNS-safe
================================ */}}
{{- define "workload.appLabel" -}}
{{- $base := include "workload.fullname" . | lower -}}
{{- regexReplaceAll "[^a-z0-9-]" $base "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* ================================
   Common labels (KHÔNG dùng cho selector)
   - Selector chỉ dùng nhãn ổn định
================================ */}}
{{- define "workload.labels" -}}
helm.sh/chart: {{ include "workload.chart" . }}
app.kubernetes.io/name: {{ include "workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ include "workload.version" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.system }}
app.kubernetes.io/part-of: {{ .Values.system | lower | trunc 63 | trimSuffix "-" }}
{{- end }}
app: {{ include "workload.appLabel" . }}
env: {{ include "workload.env" . }}
version: {{ include "workload.version" . }}
{{- with .Values.workload.extraPodLabels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end -}}

{{/* ================================
   Selector labels (ổn định, tối giản)
================================ */}}
{{- define "workload.selectorLabels" -}}
app: {{ include "workload.appLabel" . }}
{{- end -}}

{{- define "workload.matchLabels" -}}
{{ include "workload.selectorLabels" . }}
{{- end -}}

{{/* ================================
   Resource names
================================ */}}
{{- define "workload.configMapName" -}}
{{- default (printf "%s-config" (include "workload.fullname" .)) .Values.configMap.name -}}
{{- end -}}

{{- define "workload.secretName" -}}
{{- default (printf "%s-secret" (include "workload.fullname" .)) .Values.secrets.name -}}
{{- end -}}

{{- define "workload.serviceName" -}}
{{- default (include "workload.fullname" .) .Values.service.name -}}
{{- end -}}

{{/* ================================
   Kind: Deployment | StatefulSet
================================ */}}
{{- define "workload.workloadKind" -}}
{{- $k := default "Deployment" .Values.workload.kind | toString | lower -}}
{{- if eq $k "statefulset" -}}StatefulSet{{- else -}}Deployment{{- end -}}
{{- end -}}
