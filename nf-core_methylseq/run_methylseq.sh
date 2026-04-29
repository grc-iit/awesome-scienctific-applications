#!/bin/bash
# Run nf-core/methylseq on the bundled `-profile test` data set.
# Usage: run_methylseq.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/methylseq-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/methylseq/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/methylseq run complete ==="
