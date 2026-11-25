{{- define "http-workload.name" -}}
{{- $resourceName := printf "%s-%s" .root.Release.Name .name -}}
{{- if or (gt (len $resourceName) 63) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $resourceName)) -}}
{{- fail (printf "httpWorkloads.%s: release name and workload name must form a DNS label of at most 63 characters" .name) -}}
{{- end -}}
{{- $resourceName -}}
{{- end }}

{{- define "http-workload.selectorLabels" -}}
app.kubernetes.io/instance: {{ .root.Release.Name | quote }}
app.kubernetes.io/component: {{ .name | quote }}
{{- end }}

{{- define "http-workload.labels" -}}
{{- include "common.labels" (dict "root" .root "name" .name "partOf" (.workload.partOf | default "") "labels" (.workload.labels | default dict)) -}}
{{- end }}

{{- define "http-workload.validateProbes" -}}
{{- range $probeName, $probe := dict
  "readinessProbe" (.workload.readinessProbe | default dict)
  "livenessProbe" (.workload.livenessProbe | default dict)
  "startupProbe" (.workload.startupProbe | default dict)
-}}
{{- if or (hasKey $probe "exec") (hasKey $probe "tcpSocket") (hasKey $probe "grpc") -}}
{{- fail (printf "httpWorkloads.%s.%s must use an HTTP probe" $.name $probeName) -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "http-workload.readinessProbe" -}}
{{- $defaults := dict
  "httpGet" (dict "path" "/healthz/ready" "port" "http")
  "periodSeconds" 5
  "timeoutSeconds" 2
  "failureThreshold" 3
-}}
{{- $probe := mergeOverwrite $defaults (deepCopy (.workload.readinessProbe | default dict)) -}}
{{- if or (not $probe.httpGet) (not $probe.httpGet.path) (not (hasPrefix "/" $probe.httpGet.path)) -}}
{{- fail (printf "httpWorkloads.%s.readinessProbe.httpGet.path must start with /" .name) -}}
{{- end -}}
{{- toYaml $probe -}}
{{- end }}
