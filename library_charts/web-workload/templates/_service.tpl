{{- define "web-workload.service" -}}
{{- $name := .name }}
{{- $port := .port }}
{{- $readyPath := .readyPath }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}-service
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: {{ $readyPath }}
spec:
  type: ClusterIP
  selector:
    app: {{ $name }}
  ports:
    - protocol: TCP
      targetPort: {{ $port }}
      port: {{ $port }}
{{- end }}
