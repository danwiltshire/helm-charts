{{- define "http-workload.resources" -}}
{{- $root := . -}}
{{- range $name, $workload := .Values.httpWorkloads }}
{{- include "http-workload.workload" (dict "root" $root "name" $name "workload" $workload) }}
{{- end }}
{{- end }}

{{- define "http-workload.workload" -}}
{{- $service := .workload.service | default dict -}}
{{- include "http-workload.validateProbes" . -}}
{{- include "http-workload.deployment" . }}
{{- printf "\n" }}
{{- if or (not (hasKey $service "enabled")) $service.enabled }}
{{- include "http-workload.service" . }}
{{- printf "\n" }}
{{- end }}
{{- include "http-workload.poddisruptionbudget" . }}
{{- printf "\n" }}
{{- end }}
