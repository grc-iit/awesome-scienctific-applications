#!/bin/bash
# Run nf-core/scnanoseq on the bundled `-profile test` data set.
# Usage: run_scnanoseq.sh <output_dir>
set -euo pipefail
OUTDIR="${1:-/output/scnanoseq-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

nextflow run /opt/scnanoseq/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/scnanoseq run complete ==="
