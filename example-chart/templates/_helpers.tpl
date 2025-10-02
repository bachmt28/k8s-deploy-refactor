{{/*
  _helpers.tpl — clean, consistent
  - fullname: workload.fullname -> fullnameOverride -> .Release.Name (nếu != default) -> env-chartLabel
  - selector labels: app.kubernetes.io/name + app.kubernetes.io/instance
  - standard labels: version from image.tag, managed-by, helm.sh/chart
  - context labels: ONLY prefixed by .Values.labeling.prefix (e.g. "context.platform.io/")
  - rollout checksums for CM/Secret changes
*/}}

{{/* ======================== Name bits ======================== */}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.chartLabel | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "chart.image.tag" -}}
{{- .Values.workload.specs.image.tag | toString -}}
{{- end -}}

{{/* sanitize: lowercase, replace non [a-z0-9-] => -, collapse '-', trim, dedupe adjacent tokens, max 63 */}}
{{- define "chart.sanitizeName" -}}
{{- $in := . | toString -}}
{{- $s := regexReplaceAll "[^a-z0-9-]" (lower $in) "-" -}}
{{- $s = regexReplaceAll "-+" $s "-" -}}
{{- $s = trimAll "-" $s -}}
{{- $parts := splitList "-" $s -}}
{{- $out := list -}}
{{- $prev := "" -}}
{{- range $parts }}
  {{- $t := . | toString | trim -}}
  {{- if and $t (ne $t $prev) -}}
    {{- $out = append $out $t -}}
    {{- $prev = $t -}}
  {{- end -}}
{{- end -}}
{{- $joined := join "-" $out -}}
{{- $joined | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* fullname:
  1) .Values.workload.fullname
  2) .Values.fullnameOverride
  3) .Release.Name (nếu khác default "release-name"/"RELEASE-NAME")
  4) env-chartLabel
*/}}
{{- define "chart.fullname" -}}
{{- if .Values.workload.fullname -}}
  {{- include "chart.sanitizeName" .Values.workload.fullname -}}
{{- else if .Values.fullnameOverride -}}
  {{- include "chart.sanitizeName" .Values.fullnameOverride -}}
{{- else -}}
  {{- $rel := .Release.Name | default "" -}}
  {{- $relLower := lower $rel -}}
  {{- if and $rel (ne $relLower "release-name") (ne $rel "RELEASE-NAME") -}}
    {{- include "chart.sanitizeName" $rel -}}
  {{- else -}}
    {{- $env := default "" .Values.env -}}
    {{- $name := include "chart.name" . -}}
    {{- include "chart.sanitizeName" (printf "%s-%s" $env $name) -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* ======================== Labels ======================== */}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "chart.name" . }}
app.kubernetes.io/instance: {{ include "chart.fullname" . }}
{{- end -}}

{{/* version label: prefer .Values.version; fallback to image tag */}}
{{- define "chart.version" -}}
{{- $tag := include "chart.image.tag" . -}}
{{- $ver := .Values.version | toString -}}
{{- default $tag $ver -}}
{{- end -}}


{{- define "chart.standardLabels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/version: {{ include "chart.version" . | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end -}}


{{/* context labels with prefix only (no bare org/site/env/system) */}}
{{- define "chart.contextLabels" }}
{{- $p := default "" .Values.labeling.prefix }}
{{- if and $p .Values.org }}
{{ printf "%sorg" $p }}: {{ .Values.org | quote }}
{{- end }}
{{- if and $p .Values.site }}
{{ printf "%ssite" $p }}: {{ .Values.site | quote }}
{{- end }}
{{- if and $p .Values.env }}
{{ printf "%senv" $p }}: {{ .Values.env | quote }}
{{- end }}
{{- if and $p .Values.system }}
{{ printf "%ssystem" $p }}: {{ .Values.system | quote }}
{{- end }}
{{- end }}

{{- define "chart.labels" -}}
{{- $sel := fromYaml (include "chart.selectorLabels" .) -}}
{{- $std := fromYaml (include "chart.standardLabels" .) -}}
{{- $ctx := fromYaml (include "chart.contextLabels" . | default "") | default dict -}}
{{- $usr := .Values.commonLabels | default dict -}}
{{- toYaml (merge (merge (merge $sel $std) $ctx) $usr) -}}
{{- end -}}

{{- define "chart.annotations" -}}
{{- toYaml (.Values.commonAnnotations | default dict) -}}
{{- end -}}

{{/* Pod labels/annotations: ensure selector labels always present; add checksums into pod annotations */}}
{{- define "chart.podLabels" -}}
{{- toYaml (merge (fromYaml (include "chart.selectorLabels" .)) (.Values.workload.podLabels | default dict)) -}}
{{- end -}}
{{- define "chart.podAnnotations" -}}
{{- toYaml (merge (.Values.workload.podAnnotations | default dict) (fromYaml (include "chart.checksums" .) | default dict)) -}}
{{- end -}}

{{/* ======================== Names for K8s objects ======================== */}}
{{- define "chart.serviceName" -}}
{{- if .Values.service.name -}}
  {{- include "chart.sanitizeName" .Values.service.name -}}
{{- else -}}
  {{- include "chart.fullname" . -}}
{{- end -}}
{{- end -}}

{{- define "chart.headlessName" -}}
{{- if .Values.service.headlessName -}}
  {{- include "chart.sanitizeName" .Values.service.headlessName -}}
{{- else -}}
  {{- printf "%s-headless" (include "chart.fullname" .) | include "chart.sanitizeName" -}}
{{- end -}}
{{- end -}}

{{- define "chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
  {{- default (include "chart.fullname" .) .Values.serviceAccount.name | include "chart.sanitizeName" -}}
{{- else -}}
  {{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* ======================== Image & pull secrets ======================== */}}
{{- define "chart.image.name" -}}
{{- default (include "chart.name" .) .Values.workload.specs.image.name -}}
{{- end -}}
{{- define "chart.image.repository" -}}{{- .Values.workload.specs.image.repository -}}{{- end -}}
{{- define "chart.image.pullPolicy" -}}{{- .Values.workload.specs.image.pullPolicy | default "IfNotPresent" -}}{{- end -}}
{{- define "chart.image" -}}
{{- $r := include "chart.image.repository" . -}}
{{- $n := include "chart.image.name" . -}}
{{- $t := include "chart.image.tag" . -}}
{{- if $r -}}{{ printf "%s/%s:%s" $r $n $t }}{{- else -}}{{ printf "%s:%s" $n $t }}{{- end -}}
{{- end -}}
{{- define "chart.imagePullSecrets" -}}
{{- with .Values.workload.imagePullSecrets }}
imagePullSecrets:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* ======================== envFrom auto-mount ======================== */}}
{{- define "chart.envFrom" -}}
{{- $root := . -}}
{{- $out := list -}}
{{- with .Values.configMap.env -}}
  {{- if and .enabled .autoMount }}
    {{- $n := default (printf "%s-env" (include "chart.fullname" $root)) .name -}}
    {{- $out = append $out (dict "configMapRef" (dict "name" (include "chart.sanitizeName" $n))) -}}
  {{- end -}}
{{- end -}}
{{- with .Values.secrets.env -}}
  {{- if and .enabled .autoMount }}
    {{- $n := default (printf "%s-env" (include "chart.fullname" $root)) .name -}}
    {{- $out = append $out (dict "secretRef" (dict "name" (include "chart.sanitizeName" $n))) -}}
  {{- end -}}
{{- end -}}
{{- if $out }}
envFrom:
{{ toYaml $out | nindent 2 }}
{{- end -}}
{{- end -}}

{{/* ======================== API discovery ======================== */}}
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

{{/* ======================== Checksums for rollout ======================== */}}
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

{{/* ======================== Kind check ======================== */}}
{{- define "chart.isStatefulSet" -}}{{- eq (default "Deployment" .Values.workload.kind) "StatefulSet" -}}{{- end -}}
{{- define "chart.isDeployment"  -}}{{- eq (default "Deployment" .Values.workload.kind) "Deployment"  -}}{{- end -}}
