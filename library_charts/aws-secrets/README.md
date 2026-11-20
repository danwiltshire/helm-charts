# AWS secrets library chart

This Helm library chart creates namespaced External Secrets resources for AWS Secrets Manager. It does not deploy by itself or add environment variables to containers.

## Prerequisites

- External Secrets Operator and its CRDs, and Stakater Reloader, installed in the target cluster.
- AWS credentials for the External Secrets Operator with `secretsmanager:GetSecretValue` for each requested secret and, when needed, `kms:Decrypt` for its customer-managed KMS key. See the [bootstrap instructions](../../README.md#secret-access).
- Access to AWS Secrets Manager from the operator. Restrict who can create or change ExternalSecrets and SecretStores: the operator's AWS role is shared by the stores it reconciles. Kubernetes Secrets also require appropriate RBAC protection.

## Use in an application chart

Add the library as a dependency in `Chart.yaml` (adjust the relative path for your chart):

```yaml
dependencies:
  - name: aws-secrets
    version: 0.1.0
    repository: file://../../charts/aws-secrets
```

Add a template such as `templates/external-secret.yaml`:

```yaml
{ { - include "aws-secrets.resources" . } }
```

Configure secrets in chart values or an environment values file:

```yaml
awsSecrets:
  - secretName: /books/prod/auth
    region: eu-west-2
    label: books-auth
    json: true
  - secretName: /books/prod/api-token
    region: eu-west-2
    label: books-api
    json: false
    envName: API_TOKEN
```

`secretName` is the AWS secret name or ARN. `region` is required for each entry: the installed External Secrets Operator validates the SecretStore's region and does not infer it from the cluster or ARN. `label` is the name of the generated SecretStore, ExternalSecret, and Kubernetes Secret. It must be a valid Kubernetes Secret name and unique within the namespace, including across applications. Use a distinct label for each entry.

For `json: true`, the AWS value must be a JSON object; its top-level keys become Kubernetes Secret keys. For `json: false`, the entire AWS value is stored under the required `envName`. Use keys valid as Kubernetes Secret keys and environment variables, with string values. Duplicate labels in one list cause Helm rendering to fail; AWS access or invalid JSON is reported by External Secrets Operator.

Reference only the Secrets the container needs, and enable Reloader on the workload:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    secret.reloader.stakater.com/auto: "true"
spec:
  template:
    spec:
      containers:
        - name: app
          envFrom:
            - secretRef:
                name: books-auth
            - secretRef:
                name: books-api
```

Reloader watches all Secrets referenced by the workload, not just those in `awsSecrets`. If multiple `envFrom` entries contain the same key, the later entry wins. An empty `awsSecrets` list creates no resources; a referenced Secret must be provided separately if it is not configured in the list.

Run `helm dependency build <application-chart-path>` before local `helm lint` or `helm template`. Argo CD normally builds missing dependencies when rendering; the file dependency must remain within the checked-out repository. Verify that the managed Argo CD capability can build it.

The library's values file includes `helm-schema` annotations for `awsSecrets`. Generate and maintain a `values.schema.json` in each consuming application chart to validate these values; the library templates only check for duplicate labels. Rebuild the dependency before regenerating the application's schema so the generator picks up changes to the annotations. Do not skip Helm schema validation.

Each ExternalSecret polls AWS every 30 seconds and owns its generated Secret. Changes to Secret data trigger a rolling restart; polling and rollout time mean this is not a 30-second restart guarantee. Removing or renaming an entry can delete its generated Secret, so update workload references at the same time.
