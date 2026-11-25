# Common library chart

This library supplies shared helpers for application charts. Add it as a direct
dependency of any application using the `http-workload` or `ingress` libraries;
Helm makes its named templates available to those libraries at render time.

`common.name` and `common.fullname` accept `root`; `common.fullname` also accepts
an optional resource `name`. They follow Helm's generated naming convention:
`nameOverride` changes the chart name, `fullnameOverride` sets the base name,
and otherwise the release name is used when it contains the chart name or
`<release>-<chart>` is used. A resource name matching the chart name uses that
base fullname; another resource name is appended as a suffix.

`common.labels` accepts `root`, `name`, optional `partOf`, and optional `labels`.
It applies the standard application labels, with the chart's app version when
present. The `app.kubernetes.io/name` label follows `nameOverride`, and standard
labels take precedence over user-supplied labels.
