---
{{- define "mesh.trim" -}}
{{- /* Trim helper */ -}}
{{- regexReplaceAll "\s+" . "" -}}
{{- end -}}

{{- define "mesh.baseName" -}}
{{- $org := default "" .Values.org -}}
{{- $env := default "" .Values.env -}}
{{- $sys := default "" .Values.system -}}
{{- $app := default "app" .Values.appLabel -}}
{{- printf "%s-%s-%s-%s" $org $env $sys $app | trimSuffix "-" | replace "--" "-" -}}
{{- end -}}

{{- define "mesh.fullBackend" -}}
{{- /* backend host = org-env-system-appLabel-version */ -}}
{{- $base := include "mesh.baseName" . -}}
{{- $v := .version | default "v1" -}}
{{- printf "%s-%s" $base $v -}}
{{- end -}}

{{- define "mesh.backendServiceName" -}}
{{- if .Values.backendServiceNameOverride -}}
{{- .Values.backendServiceNameOverride -}}
{{- else -}}
{{- include "mesh.fullBackend" . -}}
{{- end -}}
{{- end -}}

{{- define "mesh.labels" -}}
{{- $p := .Values.labeling.prefix | default "context.platform.io/" -}}
{{- $m := dict (printf "%sorg" $p) .Values.org (printf "%ssite" $p) .Values.site (printf "%senv" $p) .Values.env (printf "%ssystem" $p) .Values.system (printf "%sapp" $p) .Values.appLabel -}}
{{- toYaml $m -}}
{{- end -}}

{{- define "mesh.portSelector" -}}
{{- /* Trả về namePort nếu có, else numberPort */ -}}
{{- $p := .Values.serviceMesh.istio.port -}}
{{- if and $p $p.namePort -}}
name: {{ $p.namePort | quote }}
{{- else if and $p $p.numberPort -}}
number: {{ $p.numberPort }}
{{- else -}}
name: "http"
{{- end -}}
{{- end -}}