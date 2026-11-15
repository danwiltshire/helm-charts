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

For non-production, use `--environment nonprod` and its matching context. Set `argocdUrl` under each environment in `cluster_bootstrap/helmfile.yaml` to its managed Argo CD server URL. The URL is required and should not have a trailing slash. Selecting an environment does not select the Kubernetes cluster.

The cluster-resources Helm release is stored in the existing `kube-system` namespace. KEDA is installed as a separate release in the `keda` namespace, which Helmfile creates if needed. IngressClasses, their parameters, the StorageClass, and the NodePool are cluster-scoped resources.

The operator Helm chart versions are pinned in `cluster_bootstrap/helmfile.yaml`. Upgrade them in a reviewed commit after checking release notes and CRD compatibility, then run `helmfile sync` against each intended cluster. This setup is manually applied and does not continuously reconcile clusters.

### Production secret access

Before deploying books in production, associate an IAM role with the External Secrets Operator service account in the production cluster. EKS Auto Mode provides the Pod Identity agent; no separate agent installation is required. This role is separate from the Argo CD capability role.

Create a role with this trust policy, replacing `<prod-cluster-name>` and leaving Pod Identity session tags enabled:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "pods.eks.amazonaws.com" },
    "Action": ["sts:AssumeRole", "sts:TagSession"],
    "Condition": {
      "StringEquals": {
        "aws:RequestTag/eks-cluster-name": "<prod-cluster-name>",
        "aws:RequestTag/kubernetes-namespace": "external-secrets",
        "aws:RequestTag/kubernetes-service-account": "external-secrets"
      }
    }
  }]
}
```

The secret ARN can be found without retrieving the secret value:

```sh
aws secretsmanager describe-secret --region eu-west-2 \
  --secret-id /k8s-books/prod/auth --query ARN --output text
```

Attach this permissions policy to the role, replacing the placeholder with that exact ARN:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "secretsmanager:GetSecretValue",
    "Resource": "<secret-arn>"
  }]
}
```

If the secret uses a customer-managed KMS key, also grant `kms:Decrypt` for that key.

Create the association before installing the operator, replacing the placeholders:

```sh
aws eks create-pod-identity-association --region eu-west-2 \
  --cluster-name <prod-cluster-name> --namespace external-secrets \
  --service-account external-secrets --role-arn <role-arn>
```

The caller needs permission to create the association and pass the role. If the operator was already running before the association existed, restart it after the association is active: `kubectl --context <prod-context> rollout restart deployment/external-secrets -n external-secrets`.

The controller's role is shared across stores it reconciles. Restrict who can create or modify ExternalSecrets and SecretStores in the cluster, and keep the role limited to intended secrets. Synced values are stored in Kubernetes Secrets and exposed to containers as environment variables, so restrict Kubernetes Secret and pod access accordingly.

## Deploying applications with Argo CD

Apply each ApplicationSet to the Argo CD installation that should manage its destination. The sets use fixed destination names: `prod` for production and `nonprod` for non-production and preview applications.

```sh
kubectl --context <prod-argocd-context> apply -f argocd/application_sets/prod_environments.yaml
kubectl --context <nonprod-argocd-context> apply -f argocd/application_sets/nonprod_environments.yaml
kubectl --context <nonprod-argocd-context> apply -f argocd/application_sets/preview_environments.yaml
```

The context must point to the cluster hosting the relevant Argo CD control plane. These commands create ApplicationSet resources in its `argocd` namespace. Argo CD then creates Applications targeting the registered cluster whose name is `prod` or `nonprod`. If a single Argo CD installation manages both clusters, apply all three sets to that one control plane instead.

The ApplicationSets label their managed namespaces with `eks.amazonaws.com/pod-readiness-gate-inject: enabled` for EKS Auto Mode. Readiness gates are injected when pods are created, not into existing pods. After the namespace label and IP target group binding exist, check the pods' `spec.readinessGates` and perform a controlled rollout if needed. On first deployment, target group binding creation is asynchronous, so verify that new pods received the gate. Before managing metadata on an existing namespace, follow [Argo CD's namespace adoption guidance](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#namespace-metadata).

> [!IMPORTANT]
> Before applying an ApplicationSet, its destination cluster must be registered with that Argo CD installation. The cluster Secret must be in the `argocd` namespace, have the label `argocd.argoproj.io/secret-type: cluster`, and include `name`, `server`, and `project` values. Set `name` to exactly `prod` or `nonprod` to match the ApplicationSet destination, and `project` to `default`. For a standard Argo CD cluster registration, `server` is the cluster's Kubernetes API endpoint URL. The EKS Argo CD capability also supports using the EKS cluster ARN as `server`; follow the registration format supported by your capability. AWS recommends using `destination.name` for readability, with the registered cluster name as its value. The Secret's Kubernetes metadata name can be a unique identifier. An `env` label is optional for these ApplicationSets because they don't use a cluster generator.

Preview applications use pull requests labeled `preview` from a GitHub repository named after the app directory. The ApplicationSet overrides `domainName` and `imageTag`, setting the latter to the seven-character PR head SHA; the corresponding image must already be published.

Preview Applications list the application repository and full PR head SHA as a reference-only source, followed by the Helm chart repository. The application source does not supply manifests or values; the chart and preview values remain in `helm-charts`. The Argo CD project must permit both repositories.

Preview Applications subscribe to GitHub comments when they are created, become synced and healthy, fail or become degraded, or start deletion. Notifications update a tagged PR comment; failure comments link to Argo CD without including error details. The deletion notification is best-effort and does not confirm cleanup has finished: Argo CD may remove the Application before the notification controller processes it. The cluster-resources chart installs the managed notification configuration and a Secret containing an AWS Secrets Manager ARN, not the private key. The `argocd` namespace must exist before installing the chart. The Argo CD capability role needs `secretsmanager:GetSecretValue` on that ARN and, for a customer-managed KMS key, `kms:Decrypt`; the GitHub App needs pull request write access to the preview repository. Apply these resources to the cluster hosting the capability that manages previews.

Creation and ready comments list the external URLs reported in the Application status, falling back to the configured preview URL when none are available. The URLs can take time to appear and may not yet be reachable.

The GitHub notification service finds pull requests associated with the preview head SHA, rather than targeting the PR number, and may comment on more than one PR sharing that commit. Notifications cannot report ApplicationSet failures that prevent an Application from being created. The preview URL in a creation or failure comment may not yet be reachable.

The ApplicationSet Git generators and preview pull request generator poll every 60 seconds. Git revision caching can delay discovery beyond the polling interval; generated Applications have a separate reconciliation interval.

The books image repository is configured separately in each file under `apps/k8s-books/envs/`. The staging image is selected by `imageTag` in `apps/k8s-books/envs/staging.yaml`; update it to a published tag to deploy another version. To render a preview locally, supply the values normally provided by the ApplicationSet:

```sh
helm template books apps/k8s-books -f apps/k8s-books/envs/preview.yaml \
  --set imageTag=f6775c6 --set domainName=k8s-books-123.preview.danforge.net
```

Install External Secrets Operator and its CRDs via the production Helmfile before syncing books. In production, the operator extracts the top-level keys of the `/k8s-books/prod/auth` JSON object into the `books-auth` Kubernetes Secret every 30 seconds. Use keys valid for Kubernetes Secret keys and environment variables, with string values. The books Deployment imports all keys using `envFrom`, and Reloader triggers a rolling restart when the Secret data changes. The interval is a polling target, not a 30-second restart guarantee; intermediate versions can be missed if updates occur between polls. Preview and other environments do not use this production secret.

All three ApplicationSets ignore Reloader's pod-template annotation when comparing workloads. This does not make Argo CD respect ignored fields during sync; verify the rollout annotation survives syncs in the managed capability. Reloader also resynchronizes watched workloads on leader restart, which can cause additional rollouts. Check synchronization without printing secret values using `kubectl --context <prod-context> get externalsecret books-auth -n k8s-books-prod` and check the rollout using `kubectl --context <prod-context> rollout status deployment/books-deployment -n k8s-books-prod`.

## Developing

### Prerequisites

- [helm](https://helm.sh/docs/intro/install/)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [helm-docs](https://github.com/norwoodj/helm-docs/)

### Setup Hooks

pre-commit install
pre-commit install-hooks
