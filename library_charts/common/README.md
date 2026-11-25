# Common library chart

This library supplies shared helpers for application charts. Add it as a direct
dependency of any application using the `http-workload` or `ingress` libraries;
Helm makes its named templates available to those libraries at render time.

`common.labels` accepts `root`, `name`, optional `partOf`, and optional `labels`.
It applies the standard application labels, with the chart's app version when
present. Standard labels take precedence over user-supplied labels.
