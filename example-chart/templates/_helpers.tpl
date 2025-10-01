{{/*
  _helpers.tpl

  Quy ước:
  - fullname: ưu tiên .Values.workload.fullname -> .Values.fullnameOverride -> .Release.Name
  - Selector labels: CHỈ gồm app.kubernetes.io/name + app.kubernetes.io/instance
  - Context labels (org/site/env/system): chỉ render khi có giá trị (env REQUIRED theo values; nếu rỗng thì không render)
  - app.kubernetes.io/version: lấy từ .Values.workload.specs.image.tag (không dùng Chart.AppVersion)
  - ServiceAccount mặc định = workload fullname
  - Có checksum annotations để rollout khi ConfigMap/Secret thay đổi
*/}}

{{/* ========== Name utils ========== */}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.chartLabel | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "chart.fullname" -}}
{{- if .Values.workload.fullname -}}
  {{- .Values.workload.fullname | trunc 63 | trimSuffix "-" -}}
{{- else if .Values.fullnameOverride -}}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* image bits */}}
{{- define "chart.image.name" -}}
{{- default (include "chart.name" .) .Values.workload.specs.image.name -}}
{{- end -}}
{{- define "chart.image.repository" -}}
{{- .Values.workload.specs.image.repository -}}
{{- end -}}
{{- define "chart.image.tag" -}}
{{- .Values.workload.specs.image.tag | toString -}}
{{- end -}}
{{- define "chart.image.pullPolicy" -}}
{{- .Values.workload.specs.image.pullPolicy | default "IfNotPresent" -}}
{{- end -}}
{{- define "chart.image" -}}
{{- $repo := include "chart.image.repository" . -}}
{{- $name := include "chart.image.name" . -}}
{{- $tag  := include "chart.image.tag" . -}}
{{- if $repo -}}
{{ printf "%s/%s:%s" $repo $name $tag }}
{{- else -}}
{{ printf "%s:%s" $name $tag }}
{{- end -}}
{{- end -}}

{{/* ========== Labels & Annotations ========== */}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ include "chart.fullname" . }}
{{- end -}}

{{- define "chart.standardLabels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/version: {{ include "chart.image.tag" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}

{{- define "chart.contextLabels" -}}
{{- if .Values.org }}org: {{ .Values.org | quote }}{{- end }}
{{- if .Values.site }}site: {{ .Values.site | quote }}{{- end }}
{{- if .Values.env  }}env: {{ .Values.env | quote }}{{- end }}
{{- if .Values.system }}system: {{ .Values.system | quote }}{{- end }}
{{- end -}}

{{- define "chart.labels" -}}
{{- $sel := fromYaml (include "chart.selectorLabels" .) -}}
{{- $std := fromYaml (include "chart.standardLabels" .) -}}
{{- $ctx := fromYaml (include "chart.contextLabels" . | default "") | default dict -}}
{{- $user := .Values.commonLabels | default dict -}}
{{- toYaml (merge (merge (merge $sel $std) $ctx) $user) -}}
{{- end -}}

{{- define "chart.annotations" -}}
{{- $common := .Values.commonAnnotations | default dict -}}
{{- toYaml $common -}}
{{- end -}}

{{/* Pod labels/annotations helper: đảm bảo selector luôn có mặt, rồi merge thêm podLabels/podAnnotations và checksum */}}
{{- define "chart.podLabels" -}}
{{- $base := fromYaml (include "chart.selectorLabels" .) -}}
{{- $more := .Values.workload.podLabels | default dict -}}
{{- toYaml (merge $base $more) -}}
{{- end -}}

{{- define "chart.podAnnotations" -}}
{{- $ann := .Values.workload.podAnnotations | default dict -}}
{{- $sum := fromYaml (include "chart.checksums" .) | default dict -}}
{{- toYaml (merge $ann $sum) -}}
{{- end -}}

{{/* ========== Names for K8s objects ========== */}}
{{- define "chart.serviceName" -}}
{{- if .Values.service.name -}}
  {{- .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- include "chart.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "chart.headlessName" -}}
{{- if .Values.service.headlessName -}}
  {{- .Values.service.headlessName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- printf "%s-headless" (include "chart.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
  {{- default (include "chart.fullname" .) .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
  {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* ========== Pull secrets / envFrom autoMount ========== */}}
{{- define "chart.imagePullSecrets" -}}
{{- with .Values.workload.imagePullSecrets }}
imagePullSecrets:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "chart.envFrom" -}}
{{- $root := . -}}
{{- $out := list -}}
{{- with .Values.configMap.env -}}
  {{- if and .enabled .autoMount }}
    {{- $n := default (printf "%s-env" (include "chart.fullname" $root)) .name -}}
    {{- $out = append $out (dict "configMapRef" (dict "name" $n)) -}}
  {{- end -}}
{{- end -}}
{{- with .Values.secrets.env -}}
  {{- if and .enabled .autoMount }}
    {{- $n := default (printf "%s-env" (include "chart.fullname" $root)) .name -}}
    {{- $out = append $out (dict "secretRef" (dict "name" $n)) -}}
  {{- end -}}
{{- end -}}
{{- if $out }}
envFrom:
{{ toYaml $out | nindent 2 }}
{{- end -}}
{{- end -}}

{{/* ========== API versions ========== */}}
{{- define "chart.hpa.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "autoscaling/v2" -}}autoscaling/v2
{{- else if .Capabilities.APIVersions.Has "autoscaling/v2beta2" -}}autoscaling/v2beta2
{{- else -}}autoscaling/v2
{{- end -}}
{{- end -}}

{{- define "chart.pdb.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" -}}policy/v1
{{- else -}}policy/v1
{{- end -}}
{{- end -}}

{{/* ========== Checksums for rollout ========== */}}
{{- define "chart.checksums" -}}
{{- $lines := dict -}}
{{- if and .Values.configMap.env.enabled .Values.configMap.env.data }}
{{- $_ := set $lines "checksum/configmap-env" (toYaml .Values.configMap.env.data | sha256sum) -}}
{{- end -}}
{{- if and .Values.configMap.file.enabled .Values.configMap.file.data }}
{{- $_ := set $lines "checksum/configmap-file" (toYaml .Values.configMap.file.data | sha256sum) -}}
{{- end -}}
{{- if and .Values.secrets.env.enabled .Values.secrets.env.stringData }}
{{- $_ := set $lines "checksum/secret-env" (toYaml .Values.secrets.env.stringData | sha256sum) -}}
{{- end -}}
{{- range $i, $s := .Values.secrets.list | default (list) }}
  {{- if and $s.enabled $s.stringData }}
    {{- $_ := set $lines (printf "checksum/secret-%s" $s.name) (toYaml $s.stringData | sha256sum) -}}
  {{- end -}}
{{- end -}}
{{- toYaml $lines -}}
{{- end -}}

{{/* ========== Misc ========== */}}
{{- define "chart.isStatefulSet" -}}{{- eq (default "Deployment" .Values.workload.kind) "StatefulSet" -}}{{- end -}}
{{- define "chart.isDeployment"  -}}{{- eq (default "Deployment" .Values.workload.kind) "Deployment"  -}}{{- end -}}
