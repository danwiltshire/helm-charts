{{- define "http-workload.deployment" -}}
{{- $workload := .workload -}}
{{- $image := $workload.image | default dict -}}
{{- $imageRef := required (printf "httpWorkloads.%s.image.repository is required" .name) $image.repository -}}
{{- if not (or $image.tag $image.digest) -}}
{{- fail (printf "httpWorkloads.%s.image requires a tag or digest" .name) -}}
{{- end -}}
{{- with $image.tag -}}
{{- $imageRef = printf "%s:%s" $imageRef . -}}
{{- end -}}
{{- with $image.digest -}}
{{- $imageRef = printf "%s@%s" $imageRef . -}}
{{- end -}}
{{- $port := required (printf "httpWorkloads.%s.port is required" .name) $workload.port -}}
{{- $resources := dict
  "requests" (dict "cpu" "100m" "memory" "128Mi")
  "limits" (dict "cpu" "1" "memory" "512Mi")
-}}
{{- $podSecurity := dict
  "seccompProfile" (dict "type" "RuntimeDefault")
-}}
{{- $security := dict
  "allowPrivilegeEscalation" false
  "readOnlyRootFilesystem" true
  "capabilities" (dict "drop" (list "ALL"))
-}}
{{- $liveness := dict
  "httpGet" (dict "path" "/healthz/live" "port" "http")
  "periodSeconds" 10
  "timeoutSeconds" 2
  "failureThreshold" 6
-}}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "http-workload.name" . }}
  labels:
    {{- include "http-workload.labels" . | nindent 4 }}
  {{- with $workload.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ $workload.replicas | default 2 }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      {{- include "http-workload.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "http-workload.labels" . | nindent 8 }}
      {{- with $workload.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      terminationGracePeriodSeconds: 30
      securityContext:
        {{- mergeOverwrite $podSecurity (deepCopy ($workload.podSecurityContext | default dict)) | toYaml | nindent 8 }}
      {{- with $workload.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $workload.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if hasKey $workload "affinity" }}
      {{- with $workload.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- else }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    {{- include "http-workload.selectorLabels" . | nindent 20 }}
                topologyKey: kubernetes.io/hostname
      {{- end }}
      containers:
        - name: {{ .name | quote }}
          image: {{ $imageRef | quote }}
          {{- with $workload.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $workload.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $workload.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ $port }}
          securityContext:
            {{- mergeOverwrite $security (deepCopy ($workload.securityContext | default dict)) | toYaml | nindent 12 }}
          resources:
            {{- mergeOverwrite $resources (deepCopy ($workload.resources | default dict)) | toYaml | nindent 12 }}
          lifecycle:
            preStop:
              sleep:
                seconds: 10
          readinessProbe:
            {{- include "http-workload.readinessProbe" . | nindent 12 }}
          livenessProbe:
            {{- mergeOverwrite $liveness (deepCopy ($workload.livenessProbe | default dict)) | toYaml | nindent 12 }}
          {{- if hasKey $workload "startupProbe" }}
          {{- $startup := dict
            "httpGet" (dict "path" "/healthz/live" "port" "http")
            "periodSeconds" 5
            "failureThreshold" 30
          }}
          startupProbe:
            {{- mergeOverwrite $startup (deepCopy ($workload.startupProbe | default dict)) | toYaml | nindent 12 }}
          {{- end }}
{{- end }}
