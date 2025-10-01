{{/*
  _helpers.tpl
  Tác giả: thuộc hạ của Đại Nguyên Soái
  Mục tiêu:
  - Chuẩn hóa tên (fullname), label/annotation, selector.
  - Hỗ trợ context org/site/env/system.
  - Hỗ trợ HPA apiVersion tự động.
  - Tiện ích tpl-render, merge labels/annotations.
*/}}

{{- define "sb.trimdash" -}}
{{- regexReplaceAll "^-+|-+$" . "" -}}
{{- end -}}

{{- define "sb.joinNonEmpty" -}}
{{- /* Join các phần tử không rỗng bằng dấu '-' */ -}}
{{- $out := list -}}
{{- range . -}}
  {{- if and (.|toString) (ne (.|toString) "") -}}
    {{- $out = append $out (.|toString) -}}
  {{- end -}}
{{- end -}}
{{- join "-" $out -}}
{{- end -}}

{{/* chartLabel chuẩn hóa (fallback về .Chart.Name nếu thiếu) */}}
{{- define "sb.chartLabel" -}}
{{- default .Chart.Name .Values.chartLabel | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Tên đầy đủ: org-site-env-system-chartLabel (lọc rỗng) */}}
{{- define "sb.fullname" -}}
{{- $parts := list .Values.org .Values.site .Values.env .Values.system (include "sb.chartLabel" .) -}}
{{- $name := include "sb.joinNonEmpty" $parts -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Tên service headless (cho StatefulSet) */}}
{{- define "sb.headlessName" -}}
{{- if .Values.service.headlessName -}}
{{- .Values.service.headlessName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-hl" (include "sb.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* ServiceAccount name */}}
{{- define "sb.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
  {{- if .Values.serviceAccount.name -}}
    {{- .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
  {{- else -}}
    {{- printf "%s-sa" (include "sb.fullname" .) | trunc 63 | trimSuffix "-" -}}
  {{- end -}}
{{- else -}}
  {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Standard Helm labels + context labels */}}
{{- define "sb.standardLabels" -}}
app.kubernetes.io/name: {{ include "sb.chartLabel" . }}
app.kubernetes.io/instance: {{ include "sb.fullname" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
# Context labels (không dùng cho selector, chỉ nhận diện)
org: {{ default "" .Values.org | quote }}
site: {{ default "" .Values.site | quote }}
env: {{ default "" .Values.env | quote }}
system: {{ default "" .Values.system | quote }}
{{- end -}}

{{/* Selector labels (ổn định để match) */}}
{{- define "sb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sb.chartLabel" . }}
app.kubernetes.io/instance: {{ include "sb.fullname" . }}
{{- end -}}

{{/* Merge labels: standard + commonLabels + extra (nếu có) */}}
{{- define "sb.labels" -}}
{{- $user := .user | default dict -}}
{{- $base := fromYaml (include "sb.standardLabels" .root) -}}
{{- $common := .root.Values.commonLabels | default dict -}}
{{- $merged := merge (merge $base $common) $user -}}
{{- toYaml $merged -}}
{{- end -}}

{{/* Merge annotations: commonAnnotations + extra */}}
{{- define "sb.annotations" -}}
{{- $user := .user | default dict -}}
{{- $common := .root.Values.commonAnnotations | default dict -}}
{{- $merged := merge $common $user -}}
{{- toYaml $merged -}}
{{- end -}}

{{/* Tiện ích tpl-render một giá trị string (cho phép value chứa template) */}}
{{- define "sb.tplrender" -}}
{{- $v := index . 0 -}}
{{- $ctx := index . 1 -}}
{{- if kindIs "string" $v -}}
{{- tpl $v $ctx -}}
{{- else -}}
{{- $v -}}
{{- end -}}
{{- end -}}

{{/* ImagePullSecrets list */}}
{{- define "sb.imagePullSecrets" -}}
{{- with .Values.workload.imagePullSecrets }}
imagePullSecrets:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* Boolean helpers cho kind */}}
{{- define "sb.isStatefulSet" -}}
{{- eq (default "Deployment" .Values.workload.kind) "StatefulSet" -}}
{{- end -}}
{{- define "sb.isDeployment" -}}
{{- eq (default "Deployment" .Values.workload.kind) "Deployment" -}}
{{- end -}}
{{- define "sb.isDaemonSet" -}}
{{- eq (default "Deployment" .Values.workload.kind) "DaemonSet" -}}
{{- end -}}

{{/* HPA apiVersion chọn theo khả năng cluster */}}
{{- define "sb.hpa.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "autoscaling/v2" -}}
autoscaling/v2
{{- else if .Capabilities.APIVersions.Has "autoscaling/v2beta2" -}}
autoscaling/v2beta2
{{- else -}}
autoscaling/v2
{{- end -}}
{{- end -}}

{{/* PDB apiVersion (K8s 1.25+ dùng policy/v1) */}}
{{- define "sb.pdb.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" -}}
policy/v1
{{- else -}}
policy/v1
{{- end -}}
{{- end -}}

{{/* Tạo name cho Service (thường = fullname) */}}
{{- define "sb.serviceName" -}}
{{- if .Values.service.name -}}
{{- .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "sb.fullname" . -}}
{{- end -}}
{{- end -}}

{{/* Render envFrom (ConfigMap/Secret) nếu được bật */}}
{{- define "sb.envFrom" -}}
{{- $root := . -}}
{{- $out := list -}}
{{- with .Values.configMap.env -}}
  {{- if .enabled }}
    {{- $name := default (printf "%s-env" (include "sb.fullname" $root)) .name -}}
    {{- $out = append $out (dict "configMapRef" (dict "name" $name)) -}}
  {{- end -}}
{{- end -}}
{{- with .Values.secrets.env -}}
  {{- if .enabled }}
    {{- $name := default (printf "%s-env" (include "sb.fullname" $root)) .name -}}
    {{- $out = append $out (dict "secretRef" (dict "name" $name)) -}}
  {{- end -}}
{{- end -}}
{{- if $out }}
envFrom:
{{ toYaml $out | nindent 2 }}
{{- end -}}
{{- end -}}

{{/* Tạo headless service spec nhanh (dùng trong StatefulSet) */}}
{{- define "sb.headless.spec" -}}
clusterIP: None
publishNotReadyAddresses: true
selector:
  {{- include "sb.selectorLabels" . | nindent 2 }}
{{- with .Values.service.ports }}
ports:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
