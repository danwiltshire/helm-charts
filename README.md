## Bootstrapping a new cluster

The `cluster_bootstrap` directory contains a Helmfile for one-time cluster setup. It installs the EKS Auto Mode internal and internet-facing ALB IngressClasses, the default gp3 EBS StorageClass, an ARM64 on-demand NodePool, and KEDA. The cluster-scoped resources are packaged in a local chart under `cluster_bootstrap/cluster-resources`; KEDA is installed separately into its own namespace. The NodePool uses the EKS Auto Mode `default` NodeClass.

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [Helmfile](https://helmfile.readthedocs.io/en/latest/)
- Access to the target Kubernetes cluster with permissions to install cluster-scoped resources and KEDA's CRDs and RBAC.
- An EKS Auto Mode cluster with the `default` NodeClass available.

Configure your kubeconfig for the new cluster, then run:

```sh
cd cluster_bootstrap
helmfile template
helmfile sync
```

The cluster-resources Helm release is stored in the existing `kube-system` namespace. KEDA is installed as a separate release in the `keda` namespace, which Helmfile creates if needed. IngressClasses, their parameters, the StorageClass, and the NodePool are cluster-scoped resources.

The KEDA Helm chart version is pinned in `cluster_bootstrap/helmfile.yaml`. Upgrade it by changing that version in a reviewed commit, checking KEDA's release notes and CRD compatibility, then running `helmfile sync` against each intended cluster. This setup is manually applied and does not continuously reconcile clusters.

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

The ApplicationSet Git generators and preview pull request generator poll every 60 seconds. Git revision caching can delay discovery beyond the polling interval; generated Applications have a separate reconciliation interval.

The books image repository is configured separately in each file under `apps/k8s-books/envs/`. The staging image is selected by `imageTag` in `apps/k8s-books/envs/staging.yaml`; update it to a published tag to deploy another version. To render a preview locally, supply the values normally provided by the ApplicationSet:

```sh
helm template books apps/k8s-books -f apps/k8s-books/envs/preview.yaml \
  --set imageTag=f6775c6 --set domainName=k8s-books-123.preview.danforge.net
```

## Developing

### Prerequisites

- [helm](https://helm.sh/docs/intro/install/)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [helm-docs](https://github.com/norwoodj/helm-docs/)

### Setup Hooks

pre-commit install
pre-commit install-hooks
