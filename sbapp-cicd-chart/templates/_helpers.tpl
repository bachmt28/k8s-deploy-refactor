{{/*
  _helpers.tpl — phiên bản refactor theo chuẩn:
  - Release/Fullname default = env-appLabel-version (sanitize, dedupe '-')
  - Selector labels REQUIRED: app.kubernetes.io/app + app.kubernetes.io/instance
  - Version label ưu tiên .Values.version; fallback image.tag
  - Context labels chỉ xuất hiện dưới prefix .Values.labeling.prefix
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

{{/* Mặc định release name theo quy ước: env-appLabel-version */}}
{{- define "chart.release.default" -}}
{{- $env := default "" .Values.env -}}
{{- $app := include "chart.name" . -}}
{{- $ver := default "" .Values.version -}}
{{- include "chart.sanitizeName" (printf "%s-%s-%s" $env $app $ver) -}}
{{- end -}}

{{/* fullname:
  1) .Values.workload.fullname
  2) .Values.fullnameOverride
  3) .Release.Name (nếu khác "release-name"/"RELEASE-NAME")
  4) env-appLabel-version  ← CHUẨN MỚI
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
    {{- include "chart.release.default" . -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/* ======================== Labels ======================== */}}

{{/* REQUIRED selector labels để match đúng như yêu cầu */}}
{{- define "chart.selectorLabels" -}}
app.kubernetes.io/app: {{ include "chart.name" . }}
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

{{/* context labels với prefix duy nhất */}}
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

{{/* Pod labels/annotations: giữ selector labels + checksums vào pod annotations */}}
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
{{- if gt $total 0 }}
volumes:
{{- if $user }}
{{ toYaml $user | nindent 2 }}
{{- end }}
{{- if $needAuto }}
  - name: {{ $autoName }}
    configMap:
      name: {{ include "chart.cmFile.name" . }}
{{- end }}
{{- end }}
{{- end -}}

{{/* ======================== ConfigMap File → VolumeMounts (robust) ======================== */}}
{{- define "chart.cmFile.volumeMounts" -}}
{{- $raw := .Values.configMap.file.mounts | default (list) -}}
{{- if and (not (kindIs "slice" $raw)) (hasKey .Values.configMap.file "mount") -}}
  {{- $raw = .Values.configMap.file.mount -}}
{{- end -}}

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

    {{- if not (kindIs "map" $m) -}}
      {{- $try := fromYaml (toString $m) -}}
      {{- if not (kindIs "map" $try) -}}
        {{- fail (printf "configMap.file.mounts[%d] must be a map with keys {key, mountPath[, readOnly]} ; got %T" $i $m) -}}
      {{- else -}}
        {{- $m = $try -}}
      {{- end -}}
    {{- end -}}

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

{{/* ======================== MERGE (DEDUPE) — VolumeMounts (auto + user) ======================== */}}
{{- define "chart.container.volumeMounts" -}}
{{- $userRaw := .Values.workload.specs.volumeMounts | default (list) -}}
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

{{- $auto := list -}}
{{- $cf := .Values.configMap.file | default dict -}}
{{- $cmEnabled := and (hasKey $cf "enabled") $cf.enabled (hasKey $cf "data") $cf.data -}}
{{- if $cmEnabled -}}
  {{- $mountsRaw := (hasKey $cf "mounts" | ternary $cf.mounts (list)) -}}
  {{- if and (not (kindIs "slice" $mountsRaw)) (hasKey $cf "mount") -}}
    {{- $mountsRaw = $cf.mount -}}
  {{- end -}}
  {{- if kindIs "slice" $mountsRaw -}}
    {{- $volName := include "chart.cmFile.volumeName" . -}}
    {{- range $i, $m := $mountsRaw }}
      {{- if not (kindIs "map" $m) -}}
        {{- $try := fromYaml (toString $m) -}}
        {{- if kindIs "map" $try -}}
          {{- $m = $try -}}
        {{- else -}}
          {{- continue -}}
        {{- end -}}
      {{- end -}}

      {{- $key := "" -}}
      {{- if hasKey $m "key" -}}{{- $key = index $m "key" -}}{{- end -}}
      {{- if not $key -}}{{- continue -}}{{- end -}}

      {{- $mp := "" -}}
      {{- if hasKey $m "mountPath" -}}
        {{- $mp = index $m "mountPath" -}}
      {{- else if hasKey $m "path" -}}
        {{- $mp = index $m "path" -}}
      {{- else if hasKey $m "dir" -}}
        {{- $dir := trimSuffix "/" (index $m "dir") -}}
        {{- $mp = printf "%s/%s" $dir $key -}}
      {{- end -}}
      {{- if not $mp -}}{{- continue -}}{{- end -}}

      {{- $ro := true -}}
      {{- if hasKey $m "readOnly" -}}{{- $ro = index $m "readOnly" -}}{{- end -}}

      {{- $auto = append $auto (dict "name" $volName "mountPath" $mp "subPath" $key "readOnly" $ro) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- $filtered := list -}}
{{- range $a := $auto }}
  {{- $an := "" -}}{{- if hasKey $a "name" -}}{{- $an = index $a "name" -}}{{- end -}}
  {{- $as := "" -}}{{- if hasKey $a "subPath" -}}{{- $as = index $a "subPath" -}}{{- end -}}
  {{- $dup := false -}}
  {{- range $u := $user }}
    {{- $un := "" -}}{{- if hasKey $u "name" -}}{{- $un = index $u "name" -}}{{- end -}}
    {{- $us := "" -}}{{- if hasKey $u "subPath" -}}{{- $us = index $u "subPath" -}}{{- end -}}
    {{- if and (eq $un $an) (eq $us $as) -}}{{- $dup = true -}}{{- end -}}
  {{- end -}}
  {{- if not $dup -}}{{- $filtered = append $filtered $a -}}{{- end -}}
{{- end -}}

{{- $total := add (len $user) (len $filtered) -}}
{{- if gt $total 0 }}
volumeMounts:
{{- if gt (len $user) 0 }}
{{ toYaml $user | nindent 2 }}
{{- end }}
{{- if gt (len $filtered) 0 }}
{{ toYaml $filtered | nindent 2 }}
{{- end }}
{{- end }}
{{- end -}}
