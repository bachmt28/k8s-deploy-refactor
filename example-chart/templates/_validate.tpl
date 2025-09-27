{{/* Validate bắt buộc */}}
{{- define "workload.validateValues" -}}
  {{- $env   := required "values.env is required" (trim (default "" .Values.env)) -}}
  {{- $label := required "values.chartLabel is required" (trim (default "" .Values.chartLabel)) -}}

  {{- $allowedEnv := list "live" "pilot" "uat" -}}
  {{- if not (has $env $allowedEnv) -}}
    {{- fail (printf "values.env must be one of %v (got %q)" $allowedEnv $env) -}}
  {{- end -}}

  {{- if contains " " $label -}}
    {{- fail "values.chartLabel must not contain spaces" -}}
  {{- end -}}
{{- end -}}
