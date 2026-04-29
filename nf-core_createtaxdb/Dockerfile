# nf-core/createtaxdb — taxonomy database build (kraken2 / centrifuge / etc.)
# https://github.com/nf-core/createtaxdb
#
# Nextflow DSL2 with conda-managed per-process environments.
# CPU-only test profile (-profile test,conda).
#
# Build:
#   docker build -t sci-hpc-base       ../base
#   docker build -t sci-nf-createtaxdb    .

FROM sci-hpc-base

ARG NF_VERSION=24.10.5
ARG JAVA_VERSION=17

RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-${JAVA_VERSION}-jre-headless \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /tmp/miniforge.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --set channel_priority strict

ENV PATH=/opt/conda/bin:${PATH}

RUN curl -L -o /usr/local/bin/nextflow https://github.com/nextflow-io/nextflow/releases/download/v${NF_VERSION}/nextflow \
    && chmod +x /usr/local/bin/nextflow \
    && nextflow info

# nf-core/createtaxdb source tree (master branch — pin to a release tag for paper reproducibility).
RUN git clone --depth 1 https://github.com/nf-core/createtaxdb.git /opt/createtaxdb

COPY run_createtaxdb.sh /opt/run_createtaxdb.sh
RUN chmod +x /opt/run_createtaxdb.sh

# Per-process conda envs are NOT materialised at build time — Nextflow
# creates them on first --use-conda run under /opt/nf-conda-cache.
ENV NXF_HOME=/opt/nf-home
ENV NXF_CONDA_CACHEDIR=/opt/nf-conda-cache
ENV PYTHONNOUSERSITE=1

CMD ["/bin/bash"]
