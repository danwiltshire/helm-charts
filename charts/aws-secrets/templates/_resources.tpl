{{- define "aws-secrets.resources" -}}
{{- $labels := dict -}}
{{- range $index, $secret := .Values.awsSecrets }}
{{- if not (kindIs "map" $secret) }}
{{- fail (printf "awsSecrets[%d] must be an object" $index) }}
{{- end }}
{{- $label := required (printf "awsSecrets[%d].label is required" $index) $secret.label }}
{{- if or (not (kindIs "string" $label)) (gt (len $label) 253) (not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$" $label)) }}
{{- fail (printf "awsSecrets[%d].label must be a valid Kubernetes Secret name" $index) }}
{{- end }}
{{- if hasKey $labels $label }}
{{- fail (printf "awsSecrets[%d].label %q is duplicated" $index $label) }}
{{- end }}
{{- $_ := set $labels $label true }}
{{- $secretName := required (printf "awsSecrets[%d].secretName is required" $index) $secret.secretName }}
{{- if not (kindIs "string" $secretName) }}
{{- fail (printf "awsSecrets[%d].secretName must be a string" $index) }}
{{- end }}
{{- $region := required (printf "awsSecrets[%d].region is required" $index) $secret.region }}
{{- if not (kindIs "string" $region) }}
{{- fail (printf "awsSecrets[%d].region must be a string" $index) }}
{{- end }}
{{- if not (kindIs "bool" $secret.json) }}
{{- fail (printf "awsSecrets[%d].json must be true or false" $index) }}
{{- end }}
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
{{- $envName := required (printf "awsSecrets[%d].envName is required for a non-JSON secret" $index) $secret.envName }}
{{- if or (not (kindIs "string" $envName)) (not (regexMatch "^[A-Za-z_][A-Za-z0-9_]*$" $envName)) }}
{{- fail (printf "awsSecrets[%d].envName must be a valid environment variable name" $index) }}
{{- end }}
  data:
    - secretKey: {{ $envName | quote }}
      remoteRef:
        key: {{ $secretName | quote }}
{{- end }}
{{- end }}
{{- end }}
