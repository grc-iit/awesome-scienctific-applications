#!/bin/bash
# Run nf-core/proteinfold on the bundled `-profile test` data set.
# Usage: run_proteinfold.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/proteinfold-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/proteinfold/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/proteinfold run complete ==="
