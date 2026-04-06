{{- /* Xây tên mặc định từ org-env-system-appLabel, bỏ field rỗng */ -}}
{{- define "mesh.nameBaseFromValues" -}}
{{- $parts := list -}}

{{- with .Values.org }}
  {{- if ne . "" }}
    {{- $parts = append $parts . }}
  {{- end }}
{{- end }}

{{- with .Values.env }}
  {{- if ne . "" }}
    {{- $parts = append $parts . }}
  {{- end }}
{{- end }}

{{- with .Values.system }}
  {{- if ne . "" }}
    {{- $parts = append $parts . }}
  {{- end }}
{{- end }}

{{- $app := .Values.appLabel | default "app" -}}
{{- $parts = append $parts $app -}}

{{- join "-" $parts -}}
{{- end -}}


{{- /* baseName = release name (nếu có) hoặc org-env-system-appLabel
      + dedupe: gộp nhiều dấu '-' thành một, cắt '-' ở đầu/cuối
*/ -}}
{{- define "mesh.baseName" -}}
{{- $raw := .Release.Name | default (include "mesh.nameBaseFromValues" .) -}}
{{- $norm := regexReplaceAll "-+" $raw "-" -}}
{{- $trim := trimAll "-" $norm -}}
{{- $trim -}}
{{- end -}}


{{- /* backend Service = <baseName>-<version> */ -}}
{{- define "mesh.backendName" -}}
{{- $base := include "mesh.baseName" . -}}
{{- $v := .version | default "v1" -}}
{{- printf "%s-%s" $base $v -}}
{{- end -}}



{{- /* Chọn port cho destination:
      - Nếu .Values.serviceMesh.istio.port là số/string -> dùng number
      - Nếu là map có field number/value -> dùng number
      - Nếu trống -> KHÔNG render gì (Istio tự pick port duy nhất từ Service)
*/ -}}
{{- define "mesh.portSelector" -}}
{{- $p := .Values.serviceMesh.istio.port | default nil -}}

{{- if not $p -}}
  {{- /* không cấu hình port -> để trống, template sẽ không render block port */ -}}

{{- else if kindIs "map" $p -}}
  {{- if hasKey $p "number" -}}
number: {{ index $p "number" }}
  {{- else if hasKey $p "value" -}}
number: {{ index $p "value" }}
  {{- else -}}
    {{- /* có name nhưng cluster không support port.name -> bỏ qua */ -}}
  {{- end }}

{{- else -}}
  {{- /* p là int/float/string -> treat như port number */ -}}
number: {{ $p }}

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
