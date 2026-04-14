# biobb_wf_md_setup — BioExcel Building Blocks MD setup pipeline.
# https://github.com/bioexcel/biobb_wf_md_setup
#
# Five-step pipeline per PDB structure:
#   1. fetch/stage PDB
#   2. fix side chains        (biobb_model)
#   3. pdb2gmx topology       (GROMACS, via biobb_gromacs)
#   4. editconf box           (GROMACS)
#   5. solvate                (GROMACS)
#
# CPU-only; GROMACS is installed via conda-forge because it is not available
# as a distro package. sci-hpc-base is reused for MPI/SSH parity with the
# rest of the repo. GROMACS itself is not MPI-parallelised in this pipeline
# — parallelism at the cluster level is achieved by sharding PDB inputs
# across workers (see docker-compose.yml).
#
# Build:
#   docker build -t sci-hpc-base        ../base
#   docker build -t sci-biobb-md-setup  .

FROM sci-hpc-base

# Miniforge (conda-forge mirror) — Docker image inherits no conda otherwise.
RUN curl -L -o /tmp/miniforge.sh \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh \
    && /opt/conda/bin/conda config --set channel_priority strict

ENV PATH=/opt/conda/bin:${PATH}

# Conda env with Python 3.10 + GROMACS 2026 + biobb packages
RUN conda create -p /opt/biobb-env python=3.10 -c conda-forge -c bioconda -y \
        gromacs=2026 \
    && /opt/conda/bin/conda run -p /opt/biobb-env \
        pip install --no-cache-dir \
            biobb_common biobb_model biobb_gromacs biobb_io \
    && conda clean -afy

# Bundle a small benchmark (1AKI lysozyme PDB) for offline self-test.
RUN mkdir -p /opt/biobb-bench \
    && curl -L -o /opt/biobb-bench/1AKI.pdb https://files.rcsb.org/download/1AKI.pdb

COPY run_md_setup.py /opt/run_md_setup.py
COPY run_batch.sh    /opt/run_batch.sh
RUN chmod +x /opt/run_md_setup.py /opt/run_batch.sh

ENV PATH=/opt/biobb-env/bin:${PATH}

CMD ["/bin/bash"]
