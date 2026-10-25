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

## Developing

### Prerequisites

- [helm](https://helm.sh/docs/intro/install/)
- [pre-commit](https://github.com/pre-commit/pre-commit)
- [helm-docs](https://github.com/norwoodj/helm-docs/)

### Setup Hooks

pre-commit install
pre-commit install-hooks
