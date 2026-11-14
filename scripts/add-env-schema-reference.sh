#!/usr/bin/env bash
# Adds a yaml-language-server schema reference to chart environment override
# files (<chart>/envs/*.yaml), pointing at the chart's values.schema.json.
# helm-schema's --add-schema-reference only handles the chart's values.yaml.
set -euo pipefail

for file in "$@"; do
  if grep -q '^# yaml-language-server: \$schema=' "$file"; then
    continue
  fi
  tmp="$(mktemp)"
  {
    echo '# yaml-language-server: $schema=../values.schema.json'
    cat "$file"
  } > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
done
