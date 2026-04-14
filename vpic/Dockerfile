# VPIC-Kokkos — Vector Particle-In-Cell plasma physics simulation
# Builds VPIC with Kokkos CUDA backend.
# Vanilla VPIC-Kokkos — no external compression libraries.
#
# Build:
#   docker build -t sci-vpic --build-arg CUDA_ARCH=80 .

FROM sci-hpc-base

ARG CUDA_ARCH=80

# Clone VPIC-Kokkos with bundled Kokkos
RUN git clone --recursive https://github.com/lanl/vpic-kokkos.git /opt/vpic-kokkos

# Build VPIC core library with Kokkos CUDA
RUN cd /opt/vpic-kokkos \
    && cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_KOKKOS_CUDA=ON \
        -DBUILD_INTERNAL_KOKKOS=ON \
        -DKokkos_ARCH_AMPERE${CUDA_ARCH}=ON \
        -DCMAKE_CXX_COMPILER="$(pwd)/kokkos/bin/nvcc_wrapper" \
    && cmake --build build -j$(nproc)

# The generated deck-compiler script omits -lcuda (CUDA driver API needed by
# Kokkos). Patch it to link against the CUDA stub so deck compilation works
# inside the container. The real libcuda.so.1 is supplied at runtime by the
# NVIDIA container toolkit.
RUN sed -i \
    's|-lkokkossimd|-lkokkossimd -L/usr/local/cuda/lib64/stubs -lcuda|' \
    /opt/vpic-kokkos/build/bin/vpic

ENV NVCC_WRAPPER_DEFAULT_COMPILER=g++
ENV PATH=/opt/vpic-kokkos/build/bin:${PATH}

CMD ["/bin/bash"]
