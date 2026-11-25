{{/*
Return the chart name, honoring nameOverride and Kubernetes name length.
*/}}
{{- define "common.name" -}}
{{- default .root.Chart.Name .root.Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Build the Helm fullname, optionally appending a distinct resource name.
*/}}
{{- define "common.fullname" -}}
{{- $root := .root -}}
{{- $name := include "common.name" (dict "root" $root) -}}
{{- $fullname := "" -}}
{{- if $root.Values.fullnameOverride -}}
{{- $fullname = $root.Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else if contains $name $root.Release.Name -}}
{{- $fullname = $root.Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $fullname = printf "%s-%s" $root.Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- $resourceName := default $root.Chart.Name (get . "name") -}}
{{- if or (eq $resourceName $root.Chart.Name) (eq $resourceName $name) -}}
{{- $fullname -}}
{{- else -}}
{{- printf "%s-%s" $fullname $resourceName -}}
{{- end -}}
{{- end }}

{{/*
Merge standard application labels with custom labels; standard values win.
*/}}
{{- define "common.labels" -}}
{{- $standard := dict
  "app.kubernetes.io/name" (include "common.name" (dict "root" .root))
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
