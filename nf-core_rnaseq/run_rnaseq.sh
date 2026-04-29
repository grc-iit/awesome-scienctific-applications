#!/bin/bash
# Run nf-core/rnaseq on the bundled `-profile test` data set.
# Usage: run_rnaseq.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/rnaseq-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/rnaseq/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/rnaseq run complete ==="
