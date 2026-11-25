# Ingress library chart

This library renders one ALB Ingress with the repository's required listener,
redirect and TLS annotations. Add `common` and `ingress` as direct application
dependencies, then include `ingress.resources` from an application template.
The Ingress uses the Helm fullname convention and common labels with component
`ingress`.

```yaml
dependencies:
  - name: common
    version: 0.1.0
    repository: file://../../library_charts/common
  - name: ingress
    version: 0.1.0
    repository: file://../../library_charts/ingress
```

```gotemplate
{{- include "ingress.resources" . }}
```

```yaml
ingress:
  internetFacing: false
  domainName: example.internal
  paths:
    - path: /
      pathType: Prefix
      serviceName: api
      servicePort: 8080
```

`internetFacing` selects `alb-internet` when true and `alb-internal` otherwise.
An empty `domainName` omits the host. Each path points to a Service named with
the Helm fullname convention: a `serviceName` matching the chart name uses the
fullname as-is, while another name is appended to it. The specified numeric
Service port must match; `pathType` defaults to `Prefix` and may also be `Exact`
or `ImplementationSpecific`. The generated Service name must be a DNS label no
longer than 63 characters. The Service must exist; this library does not inspect
workload values or create Services.
Arrays are replaced by environment overrides, so supply the complete paths
list when overriding it.

Rebuild application dependencies before regenerating its values schema. The
consuming chart's schema validates the paths; Helm rendering also checks the
required fields and combined Service name.
