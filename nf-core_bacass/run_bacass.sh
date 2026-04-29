#!/bin/bash
# Run nf-core/bacass on the bundled `-profile test` data set.
# Usage: run_bacass.sh <output_dir>
#   output_dir: working directory for this run (will be created)
set -euo pipefail
OUTDIR="${1:-/output/bacass-run}"
mkdir -p "$OUTDIR"
cd "$OUTDIR"

# Per-process conda envs land under NXF_CONDA_CACHEDIR (set in image),
# so first run materialises them — expect 5-10 min extra solve time.
nextflow run /opt/bacass/main.nf \
    -profile test,conda \
    --outdir "$OUTDIR/outputs" \
    -work-dir "$OUTDIR/work" \
    -resume

# Sanity check: bacass produces an assembly FASTA + multiqc HTML.
test -d "$OUTDIR/outputs" || { echo "FAIL: outputs/ not created"; exit 1; }
echo "=== nf-core/bacass run complete ==="
