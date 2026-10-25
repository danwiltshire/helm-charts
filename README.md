## Bootstrapping a new cluster

The `clusters` directory contains a Helmfile for one-time cluster setup. It installs the EKS Auto Mode internal and internet-facing ALB IngressClasses, the default gp3 EBS StorageClass, and KEDA. The cluster-scoped ingress and storage resources are packaged in a focused local chart under `clusters/cluster-resources`; KEDA is installed separately into its own namespace.

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [Helmfile](https://helmfile.readthedocs.io/en/latest/)
- Access to the target Kubernetes cluster with permissions to install cluster-scoped resources and KEDA's CRDs and RBAC.

Configure your kubeconfig for the new cluster, then run:

```sh
cd cluster_bootstrap
helmfile template
helmfile sync
```

The cluster-resources Helm release is stored in the existing `kube-system` namespace. KEDA is installed as a separate release in the `keda` namespace, which Helmfile creates if needed. IngressClasses, their parameters, and the StorageClass are cluster-scoped resources.

The KEDA Helm chart version is pinned in `clusters/helmfile.yaml`. Upgrade it by changing that version in a reviewed commit, checking KEDA's release notes and CRD compatibility, then running `helmfile sync` against each intended cluster. This setup is manually applied and does not continuously reconcile clusters.

## Deploying applications with Argo CD

Apply each ApplicationSet to the Argo CD installation that should manage its destination. The sets use fixed destination names: `prod` for production and `nonprod` for non-production and preview applications.

```sh
kubectl --context <prod-argocd-context> apply -f argocd/application_sets/prod_environments.yaml
kubectl --context <nonprod-argocd-context> apply -f argocd/application_sets/nonprod_environments.yaml
kubectl --context <nonprod-argocd-context> apply -f argocd/application_sets/preview_environments.yaml
```

The context must point to the cluster hosting the relevant Argo CD control plane. These commands create ApplicationSet resources in its `argocd` namespace. Argo CD then creates Applications targeting the registered cluster whose name is `prod` or `nonprod`. If a single Argo CD installation manages both clusters, apply all three sets to that one control plane instead.

> [!IMPORTANT]
> Before applying an ApplicationSet, its destination cluster must be registered with that Argo CD installation. The cluster Secret must be in the `argocd` namespace, have the label `argocd.argoproj.io/secret-type: cluster`, and include `name`, `server`, and `project` values. Set `name` to exactly `prod` or `nonprod` to match the ApplicationSet destination, and `project` to `default`. For a standard Argo CD cluster registration, `server` is the cluster's Kubernetes API endpoint URL. The EKS Argo CD capability also supports using the EKS cluster ARN as `server`; follow the registration format supported by your capability. AWS recommends using `destination.name` for readability, with the registered cluster name as its value. The Secret's Kubernetes metadata name can be a unique identifier. An `env` label is optional for these ApplicationSets because they don't use a cluster generator.

## Developing

### Prerequisites

- [helm](https://helm.sh/docs/intro/install/)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [helm-docs](https://github.com/norwoodj/helm-docs/)

### Setup Hooks

pre-commit install
pre-commit install-hooks
