# WarpX — Particle-In-Cell plasma accelerator simulation (AMReX-based)
# Builds 3D CUDA, single precision, MPI, HDF5 — vanilla WarpX.
#
# Build:
#   docker build -t sci-warpx --build-arg CUDA_ARCH=80 .

FROM sci-hpc-base

ARG CUDA_ARCH=80

RUN git clone https://github.com/BLAST-WarpX/warpx.git /opt/warpx

RUN cd /opt/warpx \
    && mkdir -p build && cd build \
    && CC=$(which gcc) CXX=$(which g++) CUDACXX=$(which nvcc) CUDAHOSTCXX=$(which g++) \
       cmake -S .. -B . \
        -DCMAKE_BUILD_TYPE=Release \
        -DWarpX_COMPUTE=CUDA \
        -DWarpX_MPI=ON \
        -DWarpX_DIMS=3 \
        -DWarpX_PRECISION=SINGLE \
        -DWarpX_PARTICLE_PRECISION=SINGLE \
        -DAMReX_HDF5=YES \
        "-DCMAKE_PREFIX_PATH=/opt/hdf5" \
        -DAMReX_CUDA_ARCH=${CUDA_ARCH} \
        "-DCMAKE_CXX_FLAGS=-mcmodel=large" \
        "-DCMAKE_CUDA_FLAGS=-Xcompiler -mcmodel=large --diag-suppress=222 --diag-suppress=221" \
    && cmake --build . -j$(nproc)

ENV PATH=/opt/warpx/build/bin:${PATH}

CMD ["/bin/bash"]
