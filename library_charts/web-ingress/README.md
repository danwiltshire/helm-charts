# Web ingress library chart

Renders, for each entry in `webIngresses`, an ALB Ingress routing to the Service `<name>-service` (as created by the `web-workload` library chart).

Annotations: `listen-ports` (80/443), `ssl-redirect: "443"` and `ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06`.

## Use in an application chart

```yaml
dependencies:
  - name: web-ingress
    version: 0.1.0
    repository: file://../../library_charts/web-ingress
```

`templates/web-ingress.yaml`:

```yaml
{{- include "web-ingress.resources" . }}
```

```yaml
webIngresses:
  - name: books
    port: 3000                # default 3000; must match the workload port
    host: books.danforge.net
    path: /                   # default
    className: alb-internet   # default
```

The Ingress is named `<name>`. Names must be unique.
