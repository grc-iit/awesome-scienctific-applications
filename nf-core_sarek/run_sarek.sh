#!/bin/bash
# Run nf-core/sarek on the bundled `-profile test` data set.
# Usage: run_sarek.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/sarek-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/sarek/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/sarek run complete ==="
