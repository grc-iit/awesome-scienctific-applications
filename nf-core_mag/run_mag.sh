#!/bin/bash
# Run nf-core/mag on the bundled `-profile test` data set.
# Usage: run_mag.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/mag-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/mag/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/mag run complete ==="
