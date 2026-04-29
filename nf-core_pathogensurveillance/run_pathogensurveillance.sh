#!/bin/bash
# Run nf-core/pathogensurveillance on the bundled `-profile test` data set.
# Usage: run_pathogensurveillance.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/pathogensurveillance-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/pathogensurveillance/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/pathogensurveillance run complete ==="
