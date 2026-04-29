#!/bin/bash
# Run nf-core/genomeqc on the bundled `-profile test` data set.
# Usage: run_genomeqc.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/genomeqc-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/genomeqc/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/genomeqc run complete ==="
