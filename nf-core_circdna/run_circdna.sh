#!/bin/bash
# Run nf-core/circdna on the bundled `-profile test` data set.
# Usage: run_circdna.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/circdna-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/circdna/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/circdna run complete ==="
