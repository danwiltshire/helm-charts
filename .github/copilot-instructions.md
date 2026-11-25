# Helm Charts

This repository contains Helm charts for applications and cluster resources, Argo CD ApplicationSets for deploying applications, and a Helmfile for bootstrapping clusters.

## Tech stack in use

### GitOps and cluster bootstrap

- Argo CD ApplicationSets define application deployments across environments.
- Helmfile manages cluster bootstrap resources.

### Helm

- Helm charts package application workloads and shared cluster resources.
- `library_charts/` contains reusable library charts.

## Project and code guidelines

- Follow the repository's existing chart conventions and keep changes focused.
- Every workload chart must include a PodDisruptionBudget with a minimum of 1 pod, unless the user or chart requirements specify otherwise.
- Applications are expected to implement /healthz/live and /healthz/ready and
  you should advise the user of this, although it can be overridden.
- Follow organisational standards. The repository's pre-commit hooks enforce these standards using Kyverno, including requirements such as specific annotations on Service resources.
- Write Kyverno CEL expressions using optional field/map access (`.?field`, `[?key]`) with `.hasValue()` for presence checks and `.orValue(default)` for comparisons. For nested optional fields, chain selectors and apply `.orValue(default)` at the end (for example, `container.?lifecycle.?preStop.?sleep.?seconds.orValue(0)`) instead of adding fallback maps at each level. Prefer this over separate existence checks followed by lookups; choose defaults that make missing values fail required-value checks.
- Before implementing chart functionality, read the contents of `library_charts/`. If a library chart may provide functionality that can be reused, ask the user before proceeding with a new implementation.
- Library charts should default to empty collections in `values.yaml` rather than example application values, and define their values schema using `helm-schema` annotations. Put usage examples in the chart README.

## Project structure

- `apps/` : Application Helm charts and environment-specific values.
- `argocd/application_sets/` : Argo CD ApplicationSet definitions.
- `cluster_bootstrap/` : Helmfile configuration and cluster bootstrap chart.
- `library_charts/` : Reusable Helm library charts; see each chart's README for usage instructions.
- `scripts/` : Repository helper scripts.

### Testing

- Run `pre-commit run --all-files`.
- Do not run any other CLI tools; they are fully covered by pre-commit.

## Resources

- `library_charts/` : Read each chart's README for usage instructions before considering or using its functionality.
