#!/bin/bash
# Run nf-core/spatialvi on the bundled `-profile test` data set.
# Usage: run_spatialvi.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/spatialvi-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/spatialvi/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/spatialvi run complete ==="
