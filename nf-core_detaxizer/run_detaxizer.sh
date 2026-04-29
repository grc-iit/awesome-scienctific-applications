#!/bin/bash
# Run nf-core/detaxizer on the bundled `-profile test` data set.
# Usage: run_detaxizer.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/detaxizer-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/detaxizer/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/detaxizer run complete ==="
