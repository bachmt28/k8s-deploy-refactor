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
{{- if .Values.org }}
org: {{ .Values.org }}
{{- end }}
{{- if .Values.env }}
env: {{ .Values.env }}
{{- end }}
{{- if .Values.site }}
site: {{ .Values.site }}
{{- end }}
{{- if .Values.system }}
system: {{ .Values.system }}
{{- end }}
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

{{/* Return SHA256 of configMap.data if enabled & non-empty; else "" */}}
{{- define "workload.configChecksum" -}}
{{- $env := .Values.configMap.env | default dict -}}
{{- $file := .Values.configMap.file | default dict -}}
{{- $sum := "" -}}
{{- if $env.data -}}
  {{- $sum = printf "%s%s" $sum (sha256sum (toYaml $env.data | trim)) -}}
{{- end -}}
{{- if $file.data -}}
  {{- $sum = printf "%s%s" $sum (sha256sum (toYaml $file.data | trim)) -}}
{{- end -}}
{{- if $sum -}}{{- sha256sum $sum -}}{{- end -}}
{{- end -}}


{{/* Return SHA256 of secrets.stringData if enabled & non-empty; else "" */}}
{{- define "workload.secretChecksum" -}}
{{- $sc := .Values.secrets | default dict -}}
{{- if and ($sc.enabled) ($sc.stringData) -}}
  {{- $s := toYaml $sc.stringData | trim -}}
  {{- if $s -}}{{- sha256sum $s -}}{{- end -}}
{{- end -}}
{{- end -}}

{{/* Build a safe image reference for the main container from values.workload.specs.image.* */}}
{{- define "workload.imageRef" -}}
{{- $repo := trim (default "" .Values.workload.specs.image.repository) -}}
{{- $name := trim (default .Values.chartLabel .Values.workload.specs.image.name) -}}
{{- $tag  := default "latest" .Values.workload.specs.image.tag -}}
{{- if $repo -}}
{{ printf "%s/%s:%s" $repo $name $tag }}
{{- else -}}
{{ printf "%s:%s" $name $tag }}
{{- end -}}
{{- end -}}

{{/* Build a safe image reference from a passed struct:
    include "workload.imageRefFrom" (dict "root" $ "img" .image)
*/}}
{{- define "workload.imageRefFrom" -}}
{{- $root := .root -}}
{{- $img  := .img  -}}
{{- $repo := trim (default "" $img.repository) -}}
{{- $name := trim (default $root.Values.chartLabel $img.name) -}}
{{- $tag  := default "latest" $img.tag -}}
{{- if $repo -}}
{{ printf "%s/%s:%s" $repo $name $tag }}
{{- else -}}
{{ printf "%s:%s" $name $tag }}
{{- end -}}
{{- end -}}

{{- define "workload.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "workload.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "workload.cmEnvName" -}}
{{- if .Values.configMap.env.name -}}
{{- .Values.configMap.env.name -}}
{{- else -}}
{{- printf "%s-env" (include "workload.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "workload.cmFileName" -}}
{{- if .Values.configMap.file.name -}}
{{- .Values.configMap.file.name -}}
{{- else -}}
{{- printf "%s-file" (include "workload.fullname" .) -}}
{{- end -}}
{{- end -}}
