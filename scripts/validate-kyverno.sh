#!/usr/bin/env bash
set -euo pipefail

for command in helm kyverno; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT

for chart_dir in apps/*/; do
  [[ -d "$chart_dir" ]] || continue
  chart_name=${chart_dir%/}
  chart_name=${chart_name##*/}
  values_files=("$chart_dir"/envs/*.yaml)
  if [[ ! -e "${values_files[0]}" ]]; then
    values_files=("")
  fi

  for values_file in "${values_files[@]}"; do
    values_name=default
    helm_args=()
    if [[ -n "$values_file" ]]; then
      values_name=${values_file##*/}
      values_name=${values_name%.*}
      helm_args+=(--values "$values_file")
      if grep -qE '^imageTag:' "$chart_dir/values.yaml" &&
        ! grep -qE '^imageTag:' "$values_file"; then
        helm_args+=(--set imageTag=kyverno-validation)
      fi
    fi

    rendered_manifest="$temporary_dir/${chart_name}-${values_name}.yaml"
    helm template "$chart_name" "$chart_dir" \
      --namespace "${chart_name}-${values_name}" \
      "${helm_args[@]}" \
      > "$rendered_manifest"
    kyverno apply policies/ --resource "$rendered_manifest"
  done
done
