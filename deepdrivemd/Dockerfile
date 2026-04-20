# DeepDriveMD — adaptive biomolecular simulation framework.
# https://github.com/DeepDriveMD/DeepDriveMD-pipeline
#
# A RADICAL-EnTK pipeline that interleaves MD simulation, representation
# learning, model selection, and an agent that steers new rounds of
# sampling. Real MD stages require GPU + OpenMM simulation scripts; this
# container uses `/bin/echo` placeholders for all four stages to validate
# the framework end-to-end (config parsing, stage sequencing, iterative
# loop) without the GPU dependency — matching the bare-metal smoke test.
#
# CPU-only in this configuration (the placeholder executables need no
# GPU). Re-wire the YAML's `molecular_dynamics_stage.executable` to a
# real OpenMM driver and add GPU reservations to `docker-compose.yml`
# for production MD use.
#
# Build:
#   docker build -t sci-hpc-base   ../base
#   docker build -t sci-deepdrivemd .

FROM sci-hpc-base

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-venv \
        python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/ddmd-env \
    && /opt/ddmd-env/bin/pip install --upgrade pip wheel

# Pinned versions mirror the bare-metal Ares recipe: pydantic v1 (DDMD's
# schema is v1-only), relaxed h5py and PyYAML constraints (repo pins do
# not build on Python 3.10).
RUN /opt/ddmd-env/bin/pip install --no-cache-dir \
        'pydantic==1.10.26' \
        'PyYAML==6.0.3' \
        'h5py==3.16.0' \
        numpy scipy MDAnalysis pathos tqdm \
        openmm==8.5.0 \
        radical.entk==1.103.0 radical.pilot==1.103.2 radical.utils==1.103.1 \
        'git+https://github.com/braceal/MD-tools.git'

# DeepDriveMD source with the self.cfg patch applied.
RUN git clone --depth 1 \
        https://github.com/DeepDriveMD/DeepDriveMD-pipeline.git /opt/DeepDriveMD
COPY deepdrivemd-selfcfg.patch /opt/DeepDriveMD/deepdrivemd-selfcfg.patch
RUN cd /opt/DeepDriveMD \
    && git apply deepdrivemd-selfcfg.patch \
    && /opt/ddmd-env/bin/pip install --no-cache-dir -e .

# Tiny benchmark input: 1FME (36-residue test structure) in sys1/
RUN mkdir -p /opt/ddmd-bench/sys1 \
    && curl -L -o /opt/ddmd-bench/sys1/comp.pdb \
        https://files.rcsb.org/download/1FME.pdb \
    && cp /opt/ddmd-bench/sys1/comp.pdb /opt/ddmd-bench/1FME-folded.pdb

COPY deepdrivemd.template.yaml /opt/deepdrivemd.template.yaml
COPY run_ddmd.sh /opt/run_ddmd.sh
RUN chmod +x /opt/run_ddmd.sh

ENV PATH=/opt/ddmd-env/bin:${PATH}

CMD ["/bin/bash"]
