#!/bin/bash
# Run nf-core/ampliseq on the bundled `-profile test` data set.
# Usage: run_ampliseq.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/ampliseq-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/ampliseq/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/ampliseq run complete ==="
