# LAMMPS molecular dynamics — Kokkos CUDA + MPI
# Vanilla LAMMPS develop branch, no external compression libraries.
#
# Build:
#   docker build -t sci-lammps --build-arg CUDA_ARCH=80 .

FROM sci-hpc-base

ARG CUDA_ARCH=80

RUN git clone --branch develop --depth 1 \
    https://github.com/lammps/lammps.git /opt/lammps

# Build LAMMPS with Kokkos CUDA
RUN cd /opt/lammps \
    && mkdir -p build && cd build \
    && cmake ../cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DPKG_KOKKOS=ON \
        -DKokkos_ENABLE_CUDA=ON \
        -DKokkos_ARCH_AMPERE${CUDA_ARCH}=ON \
        -DBUILD_MPI=ON \
        -DPKG_MOLECULE=ON \
        -DPKG_KSPACE=ON \
        -DPKG_RIGID=ON \
    && make -j$(nproc)

ENV PATH=/opt/lammps/build:${PATH}

CMD ["/bin/bash"]
