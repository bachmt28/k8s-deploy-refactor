{{/*
  _helpers.tpl — clean, consistent
  - fullname: workload.fullname -> fullnameOverride -> .Release.Name (nếu != default) -> env-appLabel
  - selector labels: app.kubernetes.io/name + app.kubernetes.io/instance
  - standard labels: version from image.tag, managed-by, helm.sh/chart
  - context labels: ONLY prefixed by .Values.labeling.prefix (e.g. "context.platform.io/")
  - rollout checksums for CM/Secret changes
*/}}

{{/* ======================== Name bits ======================== */}}
{{- define "chart.name" -}}
{{- default .Chart.Name .Values.appLabel | trunc 63 | trimSuffix "-" -}}
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
  4) env-appLabel
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
{{- $_ := set $lines "checksum/configmap-env" (toYaml .Values.configMap.env.data | sha256sum | trunc 16) -}}
{{- end -}}
{{- if and .Values.configMap.file.enabled .Values.configMap.file.data }}
{{- $_ := set $lines "checksum/configmap-file" (toYaml .Values.configMap.file.data | sha256sum | trunc 16) -}}
{{- end -}}
{{- if and .Values.secrets.env.enabled .Values.secrets.env.stringData }}
{{- $_ := set $lines "checksum/secret-env" (toYaml .Values.secrets.env.stringData | sha256sum | trunc 16) -}}
{{- end -}}
{{- range $i, $s := .Values.secrets.list | default (list) }}
  {{- if and $s.enabled $s.stringData }}
    {{- $_ := set $lines (printf "checksum/secret-%s" $s.name) (toYaml $s.stringData | sha256sum | trunc 16) -}}
  {{- end -}}
{{- end -}}
{{- toYaml $lines -}}
{{- end -}}

{{/* ======================== Kind check ======================== */}}
{{- define "chart.isStatefulSet" -}}{{- eq (default "Deployment" .Values.workload.kind) "StatefulSet" -}}{{- end -}}
{{- define "chart.isDeployment"  -}}{{- eq (default "Deployment" .Values.workload.kind) "Deployment"  -}}{{- end -}}

{{/* ======================== ConfigMap File: name & volume name ======================== */}}
{{- define "chart.cmFile.name" -}}
{{- $n := default (printf "%s-file" (include "chart.fullname" .)) .Values.configMap.file.name -}}
{{- include "chart.sanitizeName" $n -}}
{{- end -}}

{{- define "chart.cmFile.volumeName" -}}
{{- printf "%s-cmfile" (include "chart.fullname" .) | include "chart.sanitizeName" -}}
{{- end -}}

{{/* ======================== MERGE (DEDUPE) — Volumes ======================== */}}
{{- define "chart.pod.volumes" -}}
{{- $user := .Values.workload.volumes | default (list) -}}
{{- $cmEnabled := and .Values.configMap.file.enabled .Values.configMap.file.data -}}
{{- $autoName := include "chart.cmFile.volumeName" . -}}
{{- $hasAuto := false -}}
{{- if $user }}
  {{- range $v := $user }}
    {{- if eq ($v.name | default "") $autoName }}
      {{- $hasAuto = true -}}
    {{- end }}
  {{- end }}
{{- end }}
{{- $needAuto := and $cmEnabled (not $hasAuto) -}}

{{- $total := add (len $user) (ternary 1 0 $needAuto) -}}
{{- if gt $total 0 -}}
volumes:
{{- if $user }}{{ toYaml $user | nindent 2 }}{{- end }}
{{- if $needAuto }}
- name: {{ $autoName }}
  configMap:
    name: {{ include "chart.cmFile.name" . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/* ======================== ConfigMap File → VolumeMounts (robust) ======================== */}}
{{- define "chart.cmFile.volumeMounts" -}}
{{- /* Lấy mounts trực tiếp, ưu tiên .Values.configMap.file.mounts; fallback .mount */ -}}
{{- $raw := .Values.configMap.file.mounts | default (list) -}}
{{- if and (not (kindIs "slice" $raw)) (hasKey .Values.configMap.file "mount") -}}
  {{- $raw = .Values.configMap.file.mount -}}
{{- end -}}

{{- /* Chuẩn hoá về slice<map> */ -}}
{{- $mounts := list -}}
{{- if kindIs "slice" $raw -}}
  {{- range $it := $raw }}
    {{- if kindIs "map" $it -}}
      {{- $mounts = append $mounts $it -}}
    {{- else -}}
      {{- $try := fromYaml (toString $it) -}}
      {{- if kindIs "map" $try }}{{- $mounts = append $mounts $try -}}{{- end -}}
    {{- end -}}
  {{- end -}}
{{- else if kindIs "map" $raw -}}
  {{- $mounts = list $raw -}}
{{- else if kindIs "string" $raw -}}
  {{- $try := fromYaml $raw -}}
  {{- if kindIs "slice" $try -}}
    {{- $mounts = $try -}}
  {{- else if kindIs "map" $try -}}
    {{- $mounts = list $try -}}
  {{- end -}}
{{- else -}}
  {{- $mounts = list -}}
{{- end -}}

{{- if gt (len $mounts) 0 -}}
  {{- range $i, $m := $mounts }}

    {{- /* Đảm bảo phần tử là map (nếu là string thì parse) */ -}}
    {{- if not (kindIs "map" $m) -}}
      {{- $try := fromYaml (toString $m) -}}
      {{- if not (kindIs "map" $try) -}}
        {{- fail (printf "configMap.file.mounts[%d] must be a map with keys {key, mountPath[, readOnly]} ; got %T" $i $m) -}}
      {{- else -}}
        {{- $m = $try -}}
      {{- end -}}
    {{- end -}}

    {{- /* Lấy mountPath an toàn + hỗ trợ dir */ -}}
    {{- $mp := "" -}}
    {{- if hasKey $m "mountPath" -}}
      {{- $mp = index $m "mountPath" -}}
    {{- else if hasKey $m "path" -}}
      {{- $mp = index $m "path" -}}
    {{- else if hasKey $m "dir" -}}
      {{- $dir := trimSuffix "/" (index $m "dir") -}}
      {{- $keyForPath := required (printf "configMap.file.mounts[%d].key is required when using 'dir'" $i) (index $m "key") -}}
      {{- $mp = printf "%s/%s" $dir $keyForPath -}}
    {{- end -}}
    {{- $mp = required (printf "configMap.file.mounts[%d].mountPath (hoặc path/dir) is required" $i) $mp -}}

    {{- $key := required (printf "configMap.file.mounts[%d].key is required" $i) (index $m "key") -}}

    {{- $ro := true -}}
    {{- if hasKey $m "readOnly" -}}
      {{- $ro = index $m "readOnly" -}}
    {{- end -}}

- name: {{ include "chart.cmFile.volumeName" $ }}
  mountPath: {{ $mp }}
  subPath: {{ $key }}
  readOnly: {{ $ro }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/* ======================== MERGE (DEDUPE) — VolumeMounts (robust) ======================== */}}
{{- define "chart.container.volumeMounts" -}}
{{- /* user mounts (raw) */ -}}
{{- $userRaw := .Values.workload.specs.volumeMounts | default (list) -}}
{{- /* auto mounts: YAML từ helper → parse */ -}}
{{- $autoRaw := (include "chart.cmFile.volumeMounts" . | fromYaml) | default (list) -}}

{{- /* Chuẩn hoá user mounts về slice<map> */ -}}
{{- $user := list -}}
{{- if kindIs "slice" $userRaw -}}
  {{- range $u := $userRaw }}
    {{- if kindIs "map" $u -}}
      {{- $user = append $user $u -}}
    {{- else -}}
      {{- $try := fromYaml (toString $u) -}}
      {{- if kindIs "map" $try }}{{- $user = append $user $try -}}{{- end -}}
    {{- end -}}
  {{- end -}}
{{- else if kindIs "map" $userRaw -}}
  {{- $user = list $userRaw -}}
{{- else if kindIs "string" $userRaw -}}
  {{- $try := fromYaml $userRaw -}}
  {{- if kindIs "slice" $try -}}
    {{- $user = $try -}}
  {{- else if kindIs "map" $try -}}
    {{- $user = list $try -}}
  {{- end -}}
{{- end -}}

{{- /* Chuẩn hoá auto mounts về slice<map> */ -}}
{{- $auto := list -}}
{{- if kindIs "slice" $autoRaw -}}
  {{- range $a := $autoRaw }}
    {{- if kindIs "map" $a -}}
      {{- $auto = append $auto $a -}}
    {{- else -}}
      {{- $try := fromYaml (toString $a) -}}
      {{- if kindIs "map" $try }}{{- $auto = append $auto $try -}}{{- end -}}
    {{- end -}}
  {{- end -}}
{{- else if kindIs "map" $autoRaw -}}
  {{- $auto = list $autoRaw -}}
{{- else if kindIs "string" $autoRaw -}}
  {{- $try := fromYaml $autoRaw -}}
  {{- if kindIs "slice" $try -}}
    {{- $auto = $try -}}
  {{- else if kindIs "map" $try -}}
    {{- $auto = list $try -}}
  {{- end -}}
{{- end -}}

{{- /* Lọc auto trùng user theo (name, subPath) — dùng index */ -}}
{{- $filtered := list -}}
{{- range $a := $auto }}
  {{- $an := "" -}}{{- if hasKey $a "name" -}}{{- $an = index $a "name" -}}{{- end -}}
  {{- $as := "" -}}{{- if hasKey $a "subPath" -}}{{- $as = index $a "subPath" -}}{{- end -}}
  {{- $dup := false -}}
  {{- range $u := $user }}
    {{- $un := "" -}}{{- if hasKey $u "name" -}}{{- $un = index $u "name" -}}{{- end -}}
    {{- $us := "" -}}{{- if hasKey $u "subPath" -}}{{- $us = index $u "subPath" -}}{{- end -}}
    {{- if and (eq $un $an) (eq $us $as) -}}
      {{- $dup = true -}}
    {{- end -}}
  {{- end -}}
  {{- if not $dup -}}
    {{- $filtered = append $filtered $a -}}
  {{- end -}}
{{- end -}}

{{- $total := add (len $user) (len $filtered) -}}
{{- if gt $total 0 -}}
volumeMounts:
{{- if gt (len $user) 0 }}{{ toYaml $user | nindent 2 }}{{- end }}
{{- range $m := $filtered }}
- {{ toYaml $m | nindent 2 | trim }}
{{- end }}
{{- end -}}
{{- end -}}
