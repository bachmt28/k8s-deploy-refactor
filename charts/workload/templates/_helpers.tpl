{{/* name: nameOverride || Chart.Name */}}
{{- define "workload.name" -}}
{{- if .Values.nameOverride -}}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Chart.Name -}}
{{- end -}}
{{- end -}}

{{/* fullname:
   - fullnameOverride ||
   - if Release.Name contains name => Release.Name
   - else => Release.Name-name
*/}}
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

{{/* chart label (keep) */}}
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/* version: prefer image.tag, fallback AppVersion */}}
{{- define "workload.version" -}}
{{- if .Values.image.tag -}}
{{- .Values.image.tag -}}
{{- else -}}
{{- default "latest" .Chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{/* env: normalized + allow-list */}}
{{- define "workload.env" -}}
{{- $e := default "prod" .Values.env | lower -}}
{{- if not (has $e (list "prod" "uat" "pilot" "live" "dev" "stg" "qa")) -}}
prod
{{- else -}}
{{- $e -}}
{{- end -}}
{{- end -}}

{{/* app label:
   - allow override via .Values.workload.appLabel
   - else join [org, system, fullname] -> dns-safe, trunc 63
*/}}
{{- define "workload.appLabel" -}}
{{- if .Values.workload.appLabel -}}
{{- .Values.workload.appLabel | lower | regexReplaceAll "[^a-z0-9-]" . "-" | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $org := default "" .Values.org -}}
{{- $system := default "" .Values.system -}}
{{- $fullname := include "workload.fullname" . -}}
{{- $parts := list $org $system $fullname | compact -}}
{{- $joined := join "-" $parts | lower -}}
{{- $dns := regexReplaceAll "[^a-z0-9-]" $joined "-" -}}
{{- $dns | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* Common labels to apply on resources (not selectors) */}}
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

{{/* Selector labels: keep STABLE only (no version/env here) */}}
{{- define "workload.selectorLabels" -}}
app: {{ include "workload.appLabel" . }}
{{- if .Values.workload.component }}
app.kubernetes.io/component: {{ .Values.workload.component | quote }}
{{- end }}
{{- end -}}

{{- define "workload.matchLabels" -}}
{{ include "workload.selectorLabels" . }}
{{- end -}}

{{- define "workload.configMapName" -}}
{{- default (printf "%s-config" (include "workload.fullname" .)) .Values.configMap.name -}}
{{- end -}}

{{- define "workload.secretName" -}}
{{- default (printf "%s-secret" (include "workload.fullname" .)) .Values.secrets.name -}}
{{- end -}}

{{- define "workload.serviceName" -}}
{{- default (include "workload.fullname" .) .Values.service.name -}}
{{- end -}}

{{/* Kind: Deployment|StatefulSet */}}
{{- define "workload.workloadKind" -}}
{{- $kind := default "Deployment" .Values.workload.kind -}}
{{- if eq (lower $kind) "statefulset" -}}StatefulSet{{- else -}}Deployment{{- end -}}
{{- end -}}
