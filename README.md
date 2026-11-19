## Bootstrapping a new cluster

The `cluster_bootstrap` directory contains a Helmfile for one-time cluster setup. It installs the EKS Auto Mode internal and internet-facing ALB IngressClasses, the default gp3 EBS StorageClass, an ARM64 on-demand NodePool, KEDA, External Secrets Operator, and Stakater Reloader. The cluster-scoped resources are packaged in a local chart under `cluster_bootstrap/cluster-resources`; the operators are installed separately into their own namespaces. The NodePool uses the EKS Auto Mode `default` NodeClass.

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [Helmfile](https://helmfile.readthedocs.io/en/latest/)
- Access to the target Kubernetes cluster with permissions to install cluster-scoped resources and KEDA's CRDs and RBAC.
- An EKS Auto Mode cluster with the `default` NodeClass available.
- The `argocd` namespace on the cluster hosting the managed Argo CD capability.

Select `prod` or `nonprod` and the matching kubeconfig context, then run:

```sh
cd cluster_bootstrap
helmfile --environment prod --kube-context <prod-context> template
helmfile --environment prod --kube-context <prod-context> sync
```

For non-production, use `--environment nonprod` and its matching context. Set `argocdUrl` under each environment in `cluster_bootstrap/helmfile.yaml` to its managed Argo CD server URL. The URL is required and should not have a trailing slash. The selected Helmfile environment also determines the webhook secret path: `prod` uses `/argocd/prod/webhook-shared-secret`, while `nonprod` uses `/argocd/nonprod/webhook-shared-secret`. Selecting an environment does not select the Kubernetes cluster.

The cluster-resources Helm release is stored in the existing `kube-system` namespace. KEDA is installed as a separate release in the `keda` namespace, which Helmfile creates if needed. IngressClasses, their parameters, the StorageClass, and the NodePool are cluster-scoped resources.

The operator Helm chart versions are pinned in `cluster_bootstrap/helmfile.yaml`. Upgrade them in a reviewed commit after checking release notes and CRD compatibility, then run `helmfile sync` against each intended cluster. This setup is manually applied and does not continuously reconcile clusters.

### Secret access

Before deploying books in production or preview, associate an IAM role with the External Secrets Operator service account in the destination cluster. Both books production and preview ApplicationSets currently target `prod`, so that cluster's operator needs access to both secrets. The operator on the cluster hosting the managed Argo CD capability also needs access to the GitHub App private key, GitHub App metadata, and webhook shared secret described below. If this is the same cluster, grant its operator role access to all five secrets. EKS Auto Mode provides the Pod Identity agent; no separate agent installation is required. This role is separate from the Argo CD capability role.

Create a role with this trust policy, replacing `<cluster-name>` and leaving Pod Identity session tags enabled:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "pods.eks.amazonaws.com" },
    "Action": ["sts:AssumeRole", "sts:TagSession"],
    "Condition": {
      "StringEquals": {
        "aws:RequestTag/eks-cluster-name": "<cluster-name>",
        "aws:RequestTag/kubernetes-namespace": "external-secrets",
        "aws:RequestTag/kubernetes-service-account": "external-secrets"
      }
    }
  }]
}
```

Find the ARNs needed by each operator without retrieving secret values:

```sh
aws secretsmanager describe-secret --region eu-west-2 \
  --secret-id /k8s-books/prod/auth --query ARN --output text
aws secretsmanager describe-secret --region eu-west-2 \
  --secret-id /k8s-books/preview/auth --query ARN --output text
aws secretsmanager describe-secret --region eu-west-2 \
  --secret-id /github/danwiltshire/app/danforge-argocd/private-key --query ARN --output text
aws secretsmanager describe-secret --region eu-west-2 \
  --secret-id /github/danwiltshire/app/danforge-argocd/metadata --query ARN --output text
aws secretsmanager describe-secret --region eu-west-2 \
  --secret-id '/argocd/<environment>/webhook-shared-secret' --query ARN --output text
```

Attach this permissions policy to each role, replacing the placeholders with the exact ARNs needed on that cluster:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "secretsmanager:GetSecretValue",
    "Resource": ["<required-secret-arn>", "<additional-required-secret-arn>"]
  }]
}
```

If the secret uses a customer-managed KMS key, also grant `kms:Decrypt` for that key.

Create the association before installing the operator, replacing the placeholders:

```sh
aws eks create-pod-identity-association --region eu-west-2 \
  --cluster-name <cluster-name> --namespace external-secrets \
  --service-account external-secrets --role-arn <role-arn>
```

The caller needs permission to create the association and pass the role. If the operator was already running before the association existed, restart it after the association is active: `kubectl --context <cluster-context> rollout restart deployment/external-secrets -n external-secrets`.

The controller's role is shared across stores it reconciles. Restrict who can create or modify ExternalSecrets and SecretStores in the cluster, and keep the role limited to intended secrets. Synced values are stored in Kubernetes Secrets and exposed to containers as environment variables, so restrict Kubernetes Secret and pod access accordingly.

## Deploying applications with Argo CD

Apply each ApplicationSet to the Argo CD installation that should manage its destination. The sets use fixed destination names: `prod` for production and preview applications, and `nonprod` for other non-production applications.

```sh
kubectl --context <prod-argocd-context> wait --for=condition=Ready externalsecret/argocd-github-app -n argocd --timeout=120s
kubectl --context <prod-argocd-context> wait --for=condition=Ready externalsecret/argocd-webhook-creds -n argocd --timeout=120s
kubectl --context <prod-argocd-context> apply -f argocd/application_sets/prod_environments.yaml
kubectl --context <nonprod-argocd-context> apply -f argocd/application_sets/nonprod_environments.yaml
kubectl --context <prod-argocd-context> apply -f argocd/application_sets/preview_environments.yaml
```

The context must point to the cluster hosting the relevant Argo CD control plane. These commands create ApplicationSet resources in its `argocd` namespace. Argo CD then creates Applications targeting the registered cluster whose name is `prod` or `nonprod`. If a single Argo CD installation manages both clusters, apply all three sets to that one control plane instead.

The cluster-resources chart installs the GitHub App and webhook ExternalSecrets. The webhook ExternalSecret reads the entire value of `/argocd/<environment>/webhook-shared-secret` and merges it into `webhook.github.secret` in the EKS-managed `argocd-webhook-creds-secret`. The target Secret must already exist; ESO preserves its other keys and does not own or delete it. Before installing the chart, stop Terraform from managing that key: remove the `kubernetes_secret_v1_data.argocd_webhook` resource from its configuration and state without destroying it, and remove the now-unused data source. Do not leave Terraform and ESO managing the same key. Grant the operator role access to the AWS secret, then run bootstrap and wait for the ExternalSecret as above. The secret value remains managed in AWS Secrets Manager.

The ApplicationSets label their managed namespaces with `eks.amazonaws.com/pod-readiness-gate-inject: enabled` for EKS Auto Mode. Readiness gates are injected when pods are created, not into existing pods. After the namespace label and IP target group binding exist, check the pods' `spec.readinessGates` and perform a controlled rollout if needed. On first deployment, target group binding creation is asynchronous, so verify that new pods received the gate. Before managing metadata on an existing namespace, follow [Argo CD's namespace adoption guidance](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#namespace-metadata).

> [!IMPORTANT]
> Before applying an ApplicationSet, its destination cluster must be registered with that Argo CD installation. The cluster Secret must be in the `argocd` namespace, have the label `argocd.argoproj.io/secret-type: cluster`, and include `name`, `server`, and `project` values. Set `name` to exactly `prod` or `nonprod` to match the ApplicationSet destination, and `project` to `default`. For a standard Argo CD cluster registration, `server` is the cluster's Kubernetes API endpoint URL. The EKS Argo CD capability also supports using the EKS cluster ARN as `server`; follow the registration format supported by your capability. AWS recommends using `destination.name` for readability, with the registered cluster name as its value. The Secret's Kubernetes metadata name can be a unique identifier. An `env` label is optional for these ApplicationSets because they don't use a cluster generator.

Preview applications use pull requests labeled `preview` from a GitHub repository named after the app directory. The ApplicationSet overrides `domainName` and `imageTag`, setting the latter to the seven-character PR head SHA; the corresponding image must already be published.

The preview pull request generator authenticates with the `danforge-argocd`
GitHub App. The External Secret above syncs its Secrets Manager private key
and the `APP_ID` and `INSTALLATION_ID` properties of its metadata JSON secret
into the `argocd` namespace; the External Secrets Operator must be installed
and have access to both secrets. The metadata properties should contain string
values. The notification configuration separately specifies the same app and
installation IDs; update it if the metadata changes. The app installation must have
pull request read access to each preview repository. Restrict access to the
resulting Kubernetes Secret, which contains the app's private key. It is
labeled as Argo CD repository credentials for the managed capability and has
no repository URL, so it is only referenced by the preview generator.

Preview Applications list the application repository and full PR head SHA as a reference-only source, followed by the Helm chart repository. The application source does not supply manifests or values; the chart and preview values remain in `helm-charts`. The Argo CD project must permit both repositories.

Preview Applications subscribe to GitHub comments when they are created, become synced and healthy, fail or become degraded, or start deletion. Notifications update a tagged PR comment; failure comments link to Argo CD without including error details. The deletion notification is best-effort and does not confirm cleanup has finished: Argo CD may remove the Application before the notification controller processes it. The cluster-resources chart installs the managed notification configuration and a Secret containing an AWS Secrets Manager ARN, not the private key. The `argocd` namespace must exist before installing the chart. The Argo CD capability role needs `secretsmanager:GetSecretValue` on that ARN and, for a customer-managed KMS key, `kms:Decrypt`; the GitHub App needs pull request write access to the preview repository. Apply these resources to the cluster hosting the capability that manages previews.

Creation and ready comments list the external URLs reported in the Application status, falling back to the configured preview URL when none are available. The URLs can take time to appear and may not yet be reachable.

The GitHub notification service finds pull requests associated with the preview head SHA, rather than targeting the PR number, and may comment on more than one PR sharing that commit. Notifications cannot report ApplicationSet failures that prevent an Application from being created. The preview URL in a creation or failure comment may not yet be reachable.

The preview pull request generator defaults to 30-minute polling, but the
matrix requeues at the shortest child generator interval. The Git generator
defaults to three minutes upstream; the managed controller may configure a
different default. Webhooks can trigger earlier refreshes; Git revision caching
can also delay discovery. Generated Applications have a separate reconciliation
interval.

The books image repository is configured in `apps/k8s-books/values.yaml`. Production selects its image with `imageTag` in `apps/k8s-books/envs/prod.yaml`; update it to a published tag to deploy another version. To render a preview locally, supply the values normally provided by the ApplicationSet:

```sh
helm dependency build apps/k8s-books
helm template books apps/k8s-books -f apps/k8s-books/envs/preview.yaml \
  --set imageTag=f6775c6 --set domainName=k8s-books-123.preview.danforge.net
```

Install External Secrets Operator and its CRDs via the Helmfile before syncing books. Create the JSON secrets `/k8s-books/prod/auth` for production and `/k8s-books/preview/auth` for previews, and grant the corresponding operator access as described above. The operator extracts their top-level keys into a `books-auth` Kubernetes Secret in each application's namespace every 30 seconds. Use keys valid for Kubernetes Secret keys and environment variables, with string values. The books Deployment requires that Secret and imports all keys using `envFrom`; Reloader triggers a rolling restart when the Secret data changes. Pods cannot start until the Secret is synchronized. The interval is a polling target, not a 30-second restart guarantee; intermediate versions can be missed if updates occur between polls.

All three ApplicationSets ignore Reloader's pod-template annotation when comparing workloads. This does not make Argo CD respect ignored fields during sync; verify the rollout annotation survives syncs in the managed capability. Reloader also resynchronizes watched workloads on leader restart, which can cause additional rollouts. Check synchronization without printing secret values using `kubectl --context <prod-context> get externalsecret books-auth -n k8s-books-prod` and check the rollout using `kubectl --context <prod-context> rollout status deployment/books-deployment -n k8s-books-prod`.

## Developing

### Prerequisites

- [helm](https://helm.sh/docs/intro/install/)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [helm-docs](https://github.com/norwoodj/helm-docs/)
- [Kyverno CLI](https://kyverno.io/docs/kyverno-cli/) v1.20.0 or later

### Setup Hooks

pre-commit install
pre-commit install-hooks
