{{/* =========================
     Sanitize helper
     ========================= */}}
{{- define "workload._sanitize" -}}
{{- . | lower | replace "_" "-" | regexReplaceAll "[^a-z0-9-]" "-" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* =========================
     Core label from values
     ========================= */}}
{{- define "workload.mainLabel" -}}
{{- $ml := required "mainLabel is required" .Values.mainLabel -}}
{{- include "workload._sanitize" $ml -}}
{{- end -}}

{{/* =========================
     Image helpers
     ========================= */}}
{{- define "workload.image.name" -}}
{{- if .Values.workload.main.image.name -}}
  {{- include "workload._sanitize" .Values.workload.main.image.name -}}
{{- else -}}
  {{- include "workload.mainLabel" . -}}
{{- end -}}
{{- end -}}

{{- define "workload.image.repository" -}}
{{- required "workload.main.image.repository is required" .Values.workload.main.image.repository -}}
{{- end -}}

{{- define "workload.image.tag" -}}
{{- default (default "latest" .Chart.AppVersion) .Values.workload.main.image.tag -}}
{{- end -}}

{{- define "workload.image.pullPolicy" -}}
{{- default "IfNotPresent" .Values.workload.main.image.pullPolicy -}}
{{- end -}}

{{/* =========================
     Name / Fullname helpers
     ========================= */}}
{{- define "workload.name" -}}
{{- if .Values.nameOverride -}}
  {{- include "workload._sanitize" .Values.nameOverride -}}
{{- else -}}
  {{- include "workload.mainLabel" . -}}
{{- end -}}
{{- end -}}

{{- define "workload.fullname" -}}
{{- if .Values.fullnameOverride -}}
  {{- include "workload._sanitize" .Values.fullnameOverride -}}
{{- else -}}
  {{- $parts := list -}}
  {{- with .Values.org    }}{{- $parts = append $parts (include "workload._sanitize" .) }}{{- end -}}
  {{- with .Values.site   }}{{- $parts = append $parts (include "workload._sanitize" .) }}{{- end -}}
  {{- with .Values.env    }}{{- $parts = append $parts (include "workload._sanitize" .) }}{{- end -}}
  {{- with .Values.system }}{{- $parts = append $parts (include "workload._sanitize" .) }}{{- end -}}
  {{- $parts = append $parts (include "workload.mainLabel" .) -}}
  {{- join "-" $parts | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* =========================
     App label / version
     ========================= */}}
{{- define "workload.appLabel" -}}
{{- include "workload.fullname" . -}}
{{- end -}}

{{- define "workload.version" -}}
{{- include "workload.image.tag" . -}}
{{- end -}}

{{/* =========================
     Chart label
     ========================= */}}
{{- define "workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/* =========================
     Common labels
     ========================= */}}
{{- define "workload.labels" -}}
helm.sh/chart: {{ include "workload.chart" . }}
app.kubernetes.io/name: {{ include "workload.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ include "workload.version" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ include "workload.appLabel" . }}
{{- with .Values.env }}env: {{ include "workload._sanitize" . }}{{- end }}
{{- with .Values.system }}app.kubernetes.io/part-of: {{ include "workload._sanitize" . }}{{- end }}
{{- with .Values.workload.extraPodLabels }}{{ toYaml . }}{{- end }}
{{- end -}}

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
