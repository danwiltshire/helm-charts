{{- define "common.labels" -}}
{{- $standard := dict
  "app.kubernetes.io/name" .root.Chart.Name
  "app.kubernetes.io/instance" .root.Release.Name
  "app.kubernetes.io/component" .name
  "app.kubernetes.io/part-of" (.partOf | default .root.Chart.Name)
  "app.kubernetes.io/managed-by" .root.Release.Service
-}}
{{- with .root.Chart.AppVersion -}}
{{- $_ := set $standard "app.kubernetes.io/version" . -}}
{{- end -}}
{{- mergeOverwrite (deepCopy (.labels | default dict)) $standard | toYaml -}}
{{- end }}
