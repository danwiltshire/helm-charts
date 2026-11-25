# Web workload library chart

Renders, for each entry in `webWorkloads`, a Deployment, Service and PodDisruptionBudget (`minAvailable: 1`). Ingress lives in the separate `web-ingress` library chart.

ALB annotation included:

- Service: `alb.ingress.kubernetes.io/healthcheck-path` (the readiness path).

Applications must implement `/healthz/live` and `/healthz/ready` (overridable via `healthcheck`).

## Use in an application chart

```yaml
dependencies:
  - name: web-workload
    version: 0.1.0
    repository: file://../../library_charts/web-workload
```

`templates/web-workload.yaml`:

```yaml
{{- include "web-workload.resources" . }}
```

```yaml
webWorkloads:
  - name: books
    image:
      repository: 426576223955.dkr.ecr.eu-west-2.amazonaws.com/books
      tag: "3d00563"
    port: 3000                # default 3000
    replicas: 2               # default 2
    arch: arm64               # default arm64
    envFromSecrets: [books-auth]
    env:
      LOG_LEVEL: info
    healthcheck:
      livePath: /healthz/live   # default
      readyPath: /healthz/ready # default
```

Resources are named `<name>-deployment`, `<name>-service` and `<name>` (PDB). Names must be unique. The Deployment enables Stakater Reloader for referenced Secrets.

Run `helm dependency build <chart>` before local `helm template`.
