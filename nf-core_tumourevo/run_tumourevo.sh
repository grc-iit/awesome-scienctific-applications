#!/bin/bash
# Run nf-core/tumourevo on the bundled `-profile test` data set.
# Usage: run_tumourevo.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/tumourevo-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/tumourevo/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/tumourevo run complete ==="
