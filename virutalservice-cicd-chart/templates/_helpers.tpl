{{- define "mesh.trim" -}}
{{- /* Trim helper */ -}}
{{- regexReplaceAll "\\s+" . "" -}}
{{- end -}}

{{- define "mesh.baseName" -}}
{{- /* org, site, system optional — nếu trống chỉ ghép env và appLabel */ -}}
{{- $org := .Values.org | default "" -}}
{{- $site := .Values.site | default "" -}}
{{- $sys := .Values.system | default "" -}}
{{- $env := .Values.env | default "" -}}
{{- $app := .Values.appLabel | default "app" -}}
{{- $segments := list -}}
{{- if $org }}{{- $segments = append $segments $org -}}{{- end -}}
{{- if $site }}{{- $segments = append $segments $site -}}{{- end -}}
{{- if $sys }}{{- $segments = append $segments $sys -}}{{- end -}}
{{- if $env }}{{- $segments = append $segments $env -}}{{- end -}}
{{- $segments = append $segments $app -}}
{{- join "-" $segments | replace "--" "-" -}}
{{- end -}}

{{- define "mesh.fullBackend" -}}
{{- /* backend host = org-env-system-appLabel-version hoặc env-appLabel-version nếu thiếu */ -}}
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
{{- $p := .Values.serviceMesh.istio.port -}}
{{- if and $p $p.namePort -}}
name: {{ $p.namePort | quote }}
{{- else if and $p $p.numberPort -}}
number: {{ $p.numberPort }}
{{- else -}}
name: "http"
{{- end -}}
{{- end -}}
