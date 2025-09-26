{{/* name: nameOverride || Chart.Name */}}
{{- define "workload.name" -}}
{{- if .Values.nameOverride -}}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Chart.Name -}}
{{- end -}}
{{- end -}}

{{/* fullname: fullnameOverride || (Release + name, tránh lặp) */}}
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

{{/* chart label */}}
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/* version: ưu tiên image.tag, fallback AppVersion */}}
{{- define "workload.version" -}}
{{- if .Values.image.tag -}}
{{- .Values.image.tag -}}
{{- else -}}
{{- default "latest" .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{/* env: chuẩn hóa + whitelist */}}
{{- define "workload.env" -}}
{{- $e := default "prod" .Values.env | lower -}}
{{- if not (has $e (list "prod" "uat" "pilot" "live" "dev" "stg" "qa")) -}}
prod
{{- else -}}
{{- $e -}}
{{- end -}}
{{- end -}}

{{/* app label: org + system + fullname (dns-safe) hoặc override */}}
{{- define "workload.appLabel" -}}
{{- if .Values.workload.appLabel -}}
{{- .Values.workload.appLabel | lower | regexReplaceAll "[^a-z0-9-]" "-" | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $org := default "" .Values.org -}}
{{- $system := default "" .Values.system -}}
{{- $fullname := include "workload.fullname" . -}}
{{- $parts := list $org $system $fullname | compact -}}
{{- $joined := join "-" $parts | lower -}}
{{- regexReplaceAll "[^a-z0-9-]" $joined "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* labels áp cho mọi resource (không dùng cho selector) */}}
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
{{- if .Values.workload.component }}
app.kubernetes.io/component: {{ .Values.workload.component | quote }}
{{- end }}
{{- end -}}

{{/* selector ổn định: không chứa env/version */}}
{{- define "workload.selectorLabels" -}}
app: {{ include "workload.appLabel" . }}
{{- if .Values.workload.component }}
app.kubernetes.io/component: {{ .Values.workload.component | quote }}
{{- end }}
{{- end -}}
