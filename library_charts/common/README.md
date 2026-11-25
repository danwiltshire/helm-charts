# Common library chart

This library supplies shared helpers for application charts. Helm makes its
named templates available when it is a direct or transitive dependency.
The `http-workload` library depends on it; applications using `ingress` without
that dependency must add `common` themselves.

`common.name` and `common.fullname` accept `root`; `common.fullname` also accepts
an optional resource `name`. They follow Helm's generated naming convention:
`nameOverride` changes the chart name, `fullnameOverride` sets the base name,
and otherwise the release name is used when it contains the chart name or
`<release>-<chart>` is used. A resource name matching the chart name uses that
base fullname; another resource name is appended as a suffix.
Set the overrides at the consuming application's top level; the helpers receive
the application context rather than reading the library's own values. The
library's annotated defaults allow `helm-schema` to include these options in
the consuming application's generated schema.

`common.labels` accepts `root`, `name`, optional `partOf`, and optional `labels`.
It applies the standard application labels, with the chart's app version when
present. The `app.kubernetes.io/name` label follows `nameOverride`, and standard
labels take precedence over user-supplied labels.
