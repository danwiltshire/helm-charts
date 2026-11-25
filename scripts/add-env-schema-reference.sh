#!/usr/bin/env bash
# Adds a yaml-language-server schema reference to chart environment override
# files (<chart>/envs/*.yaml), pointing at the partial override schema.
# helm-schema's --add-schema-reference only handles the chart's values.yaml.
set -euo pipefail

for file in "$@"; do
  if grep -q '^# yaml-language-server: \$schema=' "$file" &&
    ! grep -q '^# yaml-language-server: \$schema=\.\./values\.schema\.json$' "$file"; then
    continue
  fi
  tmp="$(mktemp)"
  if grep -q '^# yaml-language-server: \$schema=\.\./values\.schema\.json$' "$file"; then
    sed 's|^# yaml-language-server: \$schema=\.\./values\.schema\.json$|# yaml-language-server: $schema=../values.env.schema.json|' "$file" > "$tmp"
  else
    {
      echo '# yaml-language-server: $schema=../values.env.schema.json'
      cat "$file"
    } > "$tmp"
  fi
  cat "$tmp" > "$file"
  rm -f "$tmp"
done
