#!/bin/bash
# Run nf-core/taxprofiler on the bundled `-profile test` data set.
# Usage: run_taxprofiler.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/taxprofiler-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/taxprofiler/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/taxprofiler run complete ==="
