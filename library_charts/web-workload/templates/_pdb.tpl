{{- define "web-workload.pdb" -}}
{{- $name := .name }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $name }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: {{ $name }}
{{- end }}
