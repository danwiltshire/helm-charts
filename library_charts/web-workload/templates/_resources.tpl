{{- define "web-workload.resources" -}}
{{- $names := dict -}}
{{- range $index, $w := .Values.webWorkloads }}
{{- $name := required (printf "webWorkloads[%d].name is required" $index) $w.name }}
{{- if hasKey $names $name }}
{{- fail (printf "webWorkloads[%d].name %q is duplicated" $index $name) }}
{{- end }}
{{- $_ := set $names $name true }}
{{- $health := $w.healthcheck | default dict }}
{{- $img := required (printf "webWorkloads[%d].image is required" $index) $w.image }}
{{- $ctx := dict "name" $name "workload" $w "port" ($w.port | default 3000) "livePath" ($health.livePath | default "/healthz/live") "readyPath" ($health.readyPath | default "/healthz/ready") "image" (printf "%s:%s" (required (printf "webWorkloads[%d].image.repository is required" $index) $img.repository) (required (printf "webWorkloads[%d].image.tag is required" $index) $img.tag)) }}
---
{{ include "web-workload.deployment" $ctx }}
---
{{ include "web-workload.service" $ctx }}
---
{{ include "web-workload.pdb" $ctx }}
{{- end }}
{{- end }}
