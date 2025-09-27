{{/* Validate values */}}
{{- define "workload.validateValues" -}}
  {{- $env   := required "values.env is required" (trim (default "" .Values.env)) -}}
  {{- $label := required "values.chartLabel is required" (trim (default "" .Values.chartLabel)) -}}

  {{- $allowedEnv := list "live" "pilot" "uat" -}}
  {{- if not (has $env $allowedEnv) -}}
    {{- fail (printf "values.env must be one of %v (got %q)" $allowedEnv $env) -}}
  {{- end -}}

  {{/* Guard site: bắt buộc khi workload.kind = StatefulSet */}}
  {{- if eq .Values.workload.kind "StatefulSet" -}}
    {{- if not .Values.site -}}
      {{- fail "values.site is required when workload.kind=StatefulSet" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
