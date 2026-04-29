#!/bin/bash
# Run nf-core/mhcquant on the bundled `-profile test` data set.
# Usage: run_mhcquant.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/mhcquant-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/mhcquant/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/mhcquant run complete ==="
