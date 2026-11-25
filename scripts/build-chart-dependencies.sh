#!/usr/bin/env bash
set -euo pipefail

for chart in apps/*/; do
  if [[ -f "$chart/Chart.lock" ]]; then
    helm dependency build "$chart"
  fi
done
