# nf-core/bacass — bacterial whole-genome assembly pipeline.
# https://github.com/nf-core/bacass
#
# Nextflow DSL2 with conda-managed per-process environments.
# CPU-only test profile (-profile test,conda) consumes the bundled small
# FASTQ subset and produces an assembly + annotation in ~30 min.
#
# Build:
#   docker build -t sci-hpc-base    ../base
#   docker build -t sci-nf-bacass   .

FROM sci-hpc-base

ARG NF_VERSION=24.10.5
ARG JAVA_VERSION=17

# Java 17 — required by Nextflow >= 24.
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-${JAVA_VERSION}-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# Miniforge (mamba) for conda env management.
RUN curl -L -o /tmp/miniforge.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --set channel_priority strict

ENV PATH=/opt/conda/bin:${PATH}

# Nextflow CLI.
RUN curl -L -o /usr/local/bin/nextflow https://github.com/nextflow-io/nextflow/releases/download/v${NF_VERSION}/nextflow \
    && chmod +x /usr/local/bin/nextflow \
    && nextflow info

# nf-core/bacass source tree (pinned to a concrete release).
RUN git clone --depth 1 --branch 2.4.0 \
        https://github.com/nf-core/bacass.git /opt/bacass

COPY run_bacass.sh /opt/run_bacass.sh
RUN chmod +x /opt/run_bacass.sh

# Per-process conda envs are NOT materialised at build time — Nextflow
# creates them on first --use-conda run under /opt/nf-conda-cache.
ENV NXF_HOME=/opt/nf-home
ENV NXF_CONDA_CACHEDIR=/opt/nf-conda-cache
ENV PYTHONNOUSERSITE=1

CMD ["/bin/bash"]
