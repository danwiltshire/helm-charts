{{- define "aws-secrets.resources" -}}
{{- $labels := dict -}}
{{- range $index, $secret := .Values.awsSecrets }}
{{- $label := $secret.label }}
{{- if hasKey $labels $label }}
{{- fail (printf "awsSecrets[%d].label %q is duplicated" $index $label) }}
{{- end }}
{{- $_ := set $labels $label true }}
{{- $secretName := $secret.secretName }}
{{- $region := $secret.region }}
---
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: {{ $label | quote }}
spec:
  provider:
    aws:
      service: SecretsManager
      region: {{ $region | quote }}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ $label | quote }}
spec:
  refreshPolicy: Periodic
  refreshInterval: 30s
  secretStoreRef:
    name: {{ $label | quote }}
    kind: SecretStore
  target:
    name: {{ $label | quote }}
    creationPolicy: Owner
    template:
      type: Opaque
      mergePolicy: Merge
      metadata:
        annotations: {}
        labels: {}
{{- if $secret.json }}
  dataFrom:
    - extract:
        key: {{ $secretName | quote }}
{{- else }}
  data:
    - secretKey: {{ $secret.envName | quote }}
      remoteRef:
        key: {{ $secretName | quote }}
{{- end }}
{{- end }}
{{- end }}
