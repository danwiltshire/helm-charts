# HTTP workload library chart

This library renders a stateless HTTP-enabled Deployment, an optional ClusterIP
Service and a PodDisruptionBudget for each named workload. It does not create
Ingresses, secrets, databases or other backing services.

## Usage

Add the library to the consuming application's `Chart.yaml`:

```yaml
dependencies:
  - name: http-workload
    version: 0.1.0
    repository: file://../../library_charts/http-workload
```

Add an application template, for example `templates/http-workloads.yaml`:

```gotemplate
{{- include "http-workload.resources" . }}
```

Then configure one or more workloads in the application's values:

```yaml
httpWorkloads:
  api:
    image:
      repository: example/api
      tag: "1.2.3"
    port: 8080
    replicas: 2
    partOf: orders
    envFrom:
      - secretRef:
          name: api-secrets
    annotations:
      secret.reloader.stakater.com/auto: "true"
    resources:
      requests: {cpu: 200m, memory: 256Mi}
      limits: {cpu: "1", memory: 512Mi}
  worker:
    image:
      repository: example/api
      tag: "1.2.3"
    port: 8080
    args: ["worker"]
    service:
      enabled: false
```

Each resource uses the Helm fullname convention: a workload key matching the
chart name uses the fullname as-is, while other workload keys are appended to
it (for example, `stock-prod` and `stock-prod-worker`). Generated names must be
DNS labels of at most 63 characters. These names and the instance/component
selector labels are part of the interface: changing them on an existing
Deployment can require a migration. Refer to the Service by this name from a
separately managed Ingress. An empty `httpWorkloads` map renders nothing.

Use an image tag, a `sha256` digest, or both. Pin images to an appropriate
version or digest rather than `latest`. `port` is the container's HTTP port;
`service.port` defaults to it. `service.annotations` adds Service annotations,
but the required ALB health-check path is always the readiness path.

Applications should implement `/healthz/live` and `/healthz/ready`. Override
`livenessProbe` or `readinessProbe` with Kubernetes HTTP probe fields, for
example:

```yaml
readinessProbe:
  httpGet:
    path: /ready
  timeoutSeconds: 6
startupProbe:
  failureThreshold: 60
```

Probe fields are merged with the HTTP defaults; other probe handlers are not
supported. A startup probe is rendered only when configured. The ALB
health-check path follows the readiness path. PreStop sleep is fixed at 10
seconds to meet the cluster policy, and termination grace is 30 seconds.

Each workload defaults to two replicas and a PDB with `minAvailable: 1`.
Choosing one replica prevents voluntary disruptions until another pod is
available. Resource requests and limits have conservative defaults, but must be
tuned for the application. The default security contexts use a read-only root
filesystem and drop all capabilities, but do not enforce a non-root user. Use
`podSecurityContext` or `securityContext` to adjust them for the image.
`nodeSelector`, `tolerations` and `affinity` can be provided for scheduling. By
default, pods prefer different nodes; supplying `affinity` replaces that default.

`env` and `envFrom` use Kubernetes container syntax; secret creation remains a
separate capability. `annotations` apply to the Deployment, `podAnnotations`
to its pod template, and `labels` to all generated resources and pods. Selector
labels are controlled by the library. `partOf` sets the
`app.kubernetes.io/part-of` label on all generated resources and pods; it
defaults to the consuming chart's name.

The map values and field types are annotated in `values.yaml` for the
repository's `helm-schema` hook. Rebuild the library's dependencies before the
application's dependencies, then regenerate its `values.schema.json` and validate
the final merged application and environment values. The repository's
pre-commit dependency hook performs the builds in that order. Library templates
do not independently apply that parent schema to values passed to a helper.
