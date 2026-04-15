# rna-seq-star-deseq2 — Snakemake workflow for RNA-seq differential
# expression with STAR + DESeq2.
# https://github.com/snakemake-workflows/rna-seq-star-deseq2
#
# CPU-only. Uses Snakemake's `--use-conda` to materialise per-rule
# tool environments (STAR, samtools, DESeq2, multiqc, …) on first
# run — these are NOT solved at build time so the image stays small.
# Expect an additional ~10-15 minutes of conda solves during the first
# `docker compose run --rm validate`, after which envs are cached under
# /opt/conda/envs/rnaseq-tools.
#
# Build:
#   docker build -t sci-hpc-base           ../base
#   docker build -t sci-rna-seq-star-deseq2 .

FROM sci-hpc-base

# Miniforge (includes mamba) — Snakemake's conda frontend.
RUN curl -L -o /tmp/miniforge.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --set channel_priority strict

ENV PATH=/opt/conda/bin:${PATH}

RUN conda create -p /opt/rnaseq-env -c conda-forge -c bioconda -y \
        python=3.10 snakemake=9.18.2 \
    && conda clean -afy

# Upstream workflow. Pinned to v2.2.0 (the release the bare-metal Ares
# benchmark validated against).
RUN git clone --depth 1 --branch v2.2.0 \
        https://github.com/snakemake-workflows/rna-seq-star-deseq2.git \
        /opt/rna-seq-star-deseq2

# Bundled S. cerevisiae benchmark (4 paired-end samples, ~17 MB).
COPY bench/ /opt/rnaseq-bench/

COPY run_rnaseq.sh /opt/run_rnaseq.sh
RUN chmod +x /opt/run_rnaseq.sh

ENV PATH=/opt/rnaseq-env/bin:${PATH}
ENV PYTHONNOUSERSITE=1

CMD ["/bin/bash"]
