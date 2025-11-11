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