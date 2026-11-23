#!/usr/bin/env bash
# Copyright 2025 Kamesh Sampath <kamesh.sampath@hotmail.com>
# SPDX-License-Identifier: Apache-2.0
#
# Free Edition allows only ONE SQL warehouse (the pre-created starter). This script
# patches databricks/databricks.yml to reuse it: comments out the
# resources.sql_warehouses block and replaces ${resources.sql_warehouses.streetlights_wh.id}
# with the starter warehouse id. Idempotent. On paid workspaces, skip this.
#
# Usage: bash scripts/dbx-starter-wh.sh    (or: mise run dbx:use-starter-wh)
# Env: DATABRICKS_PROFILE (default DEFAULT), BUNDLE_FILE (default databricks/databricks.yml)
set -euo pipefail

PROFILE="${DATABRICKS_PROFILE:-DEFAULT}"
BUNDLE="${BUNDLE_FILE:-databricks/databricks.yml}"

WH_ID=$(databricks sql-warehouses list --profile "$PROFILE" --output json \
  | jq -r 'first(.[] | select((.name // "") | test("starter"; "i")) | .id) // .[0].id // empty')
if [[ -z "$WH_ID" ]]; then
  echo "ERROR: no SQL warehouse found via 'databricks sql-warehouses list'" >&2
  exit 1
fi

# comment out the top-level resources.sql_warehouses block (2-space indented key)
awk '
  /^  sql_warehouses:/ { skip = 1; print "# " $0; next }
  skip && /^  [a-z_]+:/ { skip = 0 }
  skip { print "# " $0; next }
  { print }
' "$BUNDLE" > "$BUNDLE.tmp" && mv "$BUNDLE.tmp" "$BUNDLE"

sed -i "s|\${resources.sql_warehouses.streetlights_wh.id}|$WH_ID|g" "$BUNDLE"

echo "patched $BUNDLE to use existing warehouse id=$WH_ID"
echo "next: cd databricks && databricks bundle validate -t dev && databricks bundle deploy -t dev"
