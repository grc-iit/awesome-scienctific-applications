# V-pipe — virus NGS pipeline (SARS-CoV-2 / HIV).
# https://github.com/cbg-ethz/V-pipe
#
# Snakemake 7-based; the workflow itself pins tool dependencies into
# per-rule conda environments, so the container only needs Snakemake 7,
# mamba/miniforge, and the V-pipe source tree. Tool envs are materialised
# on the first run with `--use-conda`.
#
# CPU-only.
#
# Build:
#   docker build -t sci-hpc-base ../base
#   docker build -t sci-vpipe    .

FROM sci-hpc-base

# Miniforge (includes mamba) — Snakemake's conda frontend.
RUN curl -L -o /tmp/miniforge.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --set channel_priority strict

ENV PATH=/opt/conda/bin:${PATH}

# Snakemake 7 (V-pipe's load_configfile call was removed in v8+).
RUN conda create -p /opt/vpipe-env -c conda-forge -c bioconda -y \
        python=3.10 snakemake=7.32.4 \
    && conda clean -afy

# V-pipe source. Checkout a concrete release tag for reproducibility; the
# 2026-03-27 Ares run used master but this container pins to v3.0.0.
RUN git clone --depth 1 --branch v3.0.0 \
        https://github.com/cbg-ethz/V-pipe.git /opt/V-pipe

COPY run_vpipe.sh /opt/run_vpipe.sh
RUN chmod +x /opt/run_vpipe.sh

ENV PATH=/opt/vpipe-env/bin:${PATH}
# Isolate from any user-site packages (bare-metal benchmark hit this bug).
ENV PYTHONNOUSERSITE=1

CMD ["/bin/bash"]
