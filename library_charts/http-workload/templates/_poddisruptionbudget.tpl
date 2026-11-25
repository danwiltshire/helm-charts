{{- define "http-workload.poddisruptionbudget" -}}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "http-workload.name" . }}
  labels:
    {{- include "http-workload.labels" . | nindent 4 }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      {{- include "http-workload.selectorLabels" . | nindent 6 }}
{{- end }}
