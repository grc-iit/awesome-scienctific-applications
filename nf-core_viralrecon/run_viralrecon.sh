#!/bin/bash
# Run nf-core/viralrecon on the bundled `-profile test` data set.
# Usage: run_viralrecon.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/viralrecon-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/viralrecon/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/viralrecon run complete ==="
