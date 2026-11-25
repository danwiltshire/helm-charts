{{- define "web-ingress.resources" -}}
{{- $names := dict -}}
{{- range $index, $i := .Values.webIngresses }}
{{- $name := required (printf "webIngresses[%d].name is required" $index) $i.name }}
{{- if hasKey $names $name }}
{{- fail (printf "webIngresses[%d].name %q is duplicated" $index $name) }}
{{- end }}
{{- $_ := set $names $name true }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
spec:
  ingressClassName: {{ $i.className | default "alb-internet" }}
  rules:
    - http:
        paths:
          - path: {{ $i.path | default "/" }}
            pathType: Prefix
            backend:
              service:
                name: {{ $name }}-service
                port:
                  number: {{ $i.port | default 3000 }}
      {{- with $i.host }}
      host: {{ . | quote }}
      {{- end }}
{{- end }}
{{- end }}
