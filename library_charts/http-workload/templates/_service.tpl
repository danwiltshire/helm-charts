{{- define "http-workload.service" -}}
{{- $service := .workload.service | default dict -}}
{{- $readiness := include "http-workload.readinessProbe" . | fromYaml -}}
{{- $annotations := deepCopy ($service.annotations | default dict) -}}
{{- $_ := set $annotations "alb.ingress.kubernetes.io/healthcheck-path" $readiness.httpGet.path -}}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "http-workload.name" . }}
  labels:
    {{- include "http-workload.labels" . | nindent 4 }}
  annotations:
    {{- toYaml $annotations | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "http-workload.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ $service.port | default .workload.port }}
      targetPort: http
{{- end }}
