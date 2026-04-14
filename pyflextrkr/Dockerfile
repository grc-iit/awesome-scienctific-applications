# PyFLEXTRKR — Python FLEXible object TRacKeR for atmospheric feature
# tracking (mesoscale convective systems, convective cells, etc.).
# https://github.com/FlexTRKR/PyFLEXTRKR
#
# CPU-only. The upstream demo runner in tests/run_demo_tests.py downloads
# a small idealized MCS dataset at runtime and exercises the full 9-step
# pipeline; we use that as the self-test.
#
# Build:
#   docker build -t sci-hpc-base  ../base
#   docker build -t sci-pyflextrkr .

FROM sci-hpc-base

# Extra runtime deps for netCDF4 and scikit-image wheels
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-venv libhdf5-dev libnetcdf-dev libgeos-dev \
    && rm -rf /var/lib/apt/lists/*

# Dedicated venv (no conda) mirroring the bare-metal Ares recipe.
RUN python3 -m venv /opt/pyflextrkr-env \
    && /opt/pyflextrkr-env/bin/pip install --upgrade pip wheel

# Clone PyFLEXTRKR pinned to a known-working tag and editable-install.
RUN git clone --depth 1 https://github.com/FlexTRKR/PyFLEXTRKR.git /opt/PyFLEXTRKR \
    && /opt/pyflextrkr-env/bin/pip install --no-cache-dir -e /opt/PyFLEXTRKR

ENV PATH=/opt/pyflextrkr-env/bin:${PATH}
ENV PYTHONNOUSERSITE=1

COPY run_demo.sh /opt/run_demo.sh
RUN chmod +x /opt/run_demo.sh

CMD ["/bin/bash"]
