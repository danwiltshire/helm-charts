{{- define "ingress.resources" -}}
{{- $root := . -}}
{{- $ingress := .Values.ingress | default dict -}}
{{- $paths := required "ingress.paths must contain at least one route" $ingress.paths -}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" (dict "root" .) | quote }}
  labels:
    {{- include "common.labels" (dict "root" . "name" "ingress") | nindent 4 }}
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
spec:
  ingressClassName: {{ ternary "alb-internet" "alb-internal" ($ingress.internetFacing | default false) }}
  rules:
    - http:
        paths:
          {{- range $index, $route := $paths }}
          {{- $path := required (printf "ingress.paths[%d].path is required" $index) $route.path }}
          {{- $serviceName := required (printf "ingress.paths[%d].serviceName is required" $index) $route.serviceName }}
          {{- $serviceName = include "common.fullname" (dict "root" $root "name" $serviceName) }}
          {{- if or (gt (len $serviceName) 63) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $serviceName)) }}
          {{- fail (printf "ingress.paths[%d].serviceName: generated Service name must be a DNS label of at most 63 characters" $index) }}
          {{- end }}
          - path: {{ $path | quote }}
            pathType: {{ $route.pathType | default "Prefix" | quote }}
            backend:
              service:
                name: {{ $serviceName | quote }}
                port:
                  number: {{ required (printf "ingress.paths[%d].servicePort is required" $index) $route.servicePort }}
      {{- end }}
      {{- with $ingress.domainName }}
      host: {{ . | quote }}
      {{- end }}
{{- end }}
