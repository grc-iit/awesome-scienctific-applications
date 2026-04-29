#!/bin/bash
# Run nf-core/differentialabundance on the bundled `-profile test` data set.
# Usage: run_differentialabundance.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/differentialabundance-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/differentialabundance/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/differentialabundance run complete ==="
