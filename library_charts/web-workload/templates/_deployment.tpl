{{- define "web-workload.deployment" -}}
{{- $name := .name }}
{{- $w := .workload }}
{{- $port := .port }}
{{- $image := .image }}
{{- $livePath := .livePath }}
{{- $readyPath := .readyPath }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $name }}-deployment
  annotations:
    secret.reloader.stakater.com/auto: "true"
spec:
  selector:
    matchLabels:
      app: {{ $name }}
  replicas: {{ $w.replicas | default 2 }}
  template:
    metadata:
      labels:
        app: {{ $name }}
    spec:
      terminationGracePeriodSeconds: 30
      nodeSelector:
        kubernetes.io/arch: {{ $w.arch | default "arm64" }}
      containers:
        - name: {{ $name }}
          image: {{ $image | quote }}
          {{- with $w.envFromSecrets }}
          envFrom:
            {{- range . }}
            - secretRef:
                name: {{ . | quote }}
            {{- end }}
          {{- end }}
          {{- with $w.env }}
          env:
            {{- range $k, $v := . }}
            - name: {{ $k }}
              value: {{ $v | quote }}
            {{- end }}
          {{- end }}
          lifecycle:
            preStop:
              sleep:
                seconds: 10
          ports:
            - name: http
              containerPort: {{ $port }}
          readinessProbe:
            httpGet:
              path: {{ $readyPath }}
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: {{ $livePath }}
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 6
          {{- with $w.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end }}
