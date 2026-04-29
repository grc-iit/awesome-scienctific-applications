#!/bin/bash
# Run nf-core/nascent on the bundled `-profile test` data set.
# Usage: run_nascent.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/nascent-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/nascent/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/nascent run complete ==="
