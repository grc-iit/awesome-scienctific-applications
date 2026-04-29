#!/bin/bash
# Run nf-core/cutandrun on the bundled `-profile test` data set.
# Usage: run_cutandrun.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/cutandrun-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/cutandrun/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/cutandrun run complete ==="
