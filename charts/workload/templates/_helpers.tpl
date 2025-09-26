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

{{- define "workload.labels" -}}
helm.sh/chart: {{ include "workload.chart" . }}
{{- with .Chart.AppVersion }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Values.workload.component }}
app.kubernetes.io/component: {{ .Values.workload.component | quote }}
{{- end }}
{{- end -}}

{{- define "workload.appLabel" -}}
{{- default (include "workload.fullname" .) .Values.workload.appLabel -}}
{{- end -}}

{{- define "workload.selectorLabels" -}}
app: {{ include "workload.appLabel" . }}
{{- with .Values.workload.version }}
version: {{ . | quote }}
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

{{- define "workload.workloadKind" -}}
{{- $kind := default "Deployment" .Values.workload.kind -}}
{{- if eq (lower $kind) "statefulset" -}}StatefulSet{{- else -}}Deployment{{- end -}}
{{- end -}}
