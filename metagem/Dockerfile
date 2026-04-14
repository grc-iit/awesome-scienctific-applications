# metaGEM — Snakemake workflow for genome-scale metabolic reconstruction
# from metagenomic sequencing data.
# https://github.com/franciscozorrilla/metaGEM
#
# CPU-only. Container focuses on the quality-filtering (qfilter) stage,
# which is metaGEM's default target and exercises fastp + the Snakemake
# DAG without pulling in all downstream tools (megahit, concoct, GTDBTk,
# COBRApy, etc.). The full pipeline is orders of magnitude larger; users
# enable downstream rules by pointing `snakemake` at different targets.
#
# Build:
#   docker build -t sci-hpc-base ../base
#   docker build -t sci-metagem  .

FROM sci-hpc-base

# Miniforge (includes mamba)
RUN curl -L -o /tmp/miniforge.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --set channel_priority strict

ENV PATH=/opt/conda/bin:${PATH}

# Snakemake 9 (matches the bare-metal benchmark recipe) + fastp for qfilter.
RUN conda create -p /opt/metagem-env -c conda-forge -c bioconda -y \
        python=3.10 snakemake=9.18.2 \
    && conda create -n metagem -c bioconda -c conda-forge -y \
        fastp=0.23 \
    && conda clean -afy

# metaGEM source, with the conda-activate patch applied. Upstream still
# uses the pre-4.4 `source activate` idiom which breaks on newer conda;
# the patch rewrites it to `conda activate` inside `conda shell.bash hook`.
RUN git clone --depth 1 https://github.com/franciscozorrilla/metaGEM.git /opt/metaGEM
COPY metagem-conda-activate.patch /opt/metaGEM/metagem-conda-activate.patch
RUN cd /opt/metaGEM && git apply metagem-conda-activate.patch

COPY run_metagem.sh /opt/run_metagem.sh
RUN chmod +x /opt/run_metagem.sh

ENV PATH=/opt/metagem-env/bin:${PATH}

CMD ["/bin/bash"]
