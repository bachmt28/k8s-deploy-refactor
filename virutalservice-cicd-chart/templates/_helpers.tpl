{{- define "mesh.baseName" -}}
{{- /* env-appLabel */ -}}
{{- $env := .Values.env | default "env" -}}
{{- $app := .Values.appLabel | default "app" -}}
{{- printf "%s-%s" $env $app -}}
{{- end -}}

{{- define "mesh.backendName" -}}
{{- /* backend Service = env-appLabel-version */ -}}
{{- $base := include "mesh.baseName" . -}}
{{- $v := .version | default "v1" -}}
{{- printf "%s-%s" $base $v -}}
{{- end -}}

{{- define "mesh.portSelector" -}}
{{- $p := .Values.serviceMesh.istio.port -}}
{{- if and $p $p.name -}}
name: {{ $p.name | quote }}
{{- else if and $p $p.number -}}
number: {{ $p.number }}
{{- else -}}
name: "http"
{{- end -}}
{{- end -}}

{{- /* Build regex cho Cookie header: (^|;\s*)name=value([;\s]|$)
      Hỗ trợ exact/prefix/regex cho phần value */ -}}
{{- define "mesh.cookieRegex" -}}
{{- $name := .name -}}
{{- $match := .match | default "exact" -}}
{{- $val := .value | default "" -}}
{{- if eq $match "prefix" -}}
{{- printf "(^|;\\s*)%s=%s[^;]*([;\\s]|$)" $name $val -}}
{{- else if eq $match "regex" -}}
{{- printf "(^|;\\s*)%s=%s([;\\s]|$)" $name $val -}}
{{- else -}}
{{- /* exact */ -}}
{{- printf "(^|;\\s*)%s=%s([;\\s]|$)" $name $val -}}
{{- end -}}
{{- end -}}
