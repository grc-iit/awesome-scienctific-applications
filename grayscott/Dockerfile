# Gray-Scott reaction-diffusion simulation
# Standalone CUDA + MPI + HDF5 — no external simulation framework required.
#
# Build:
#   docker build -t sci-grayscott --build-arg CUDA_ARCH=80 .
#   (use CUDA_ARCH=90 for H100, 80 for A100, 70 for V100)

FROM sci-hpc-base

ARG CUDA_ARCH=80

WORKDIR /opt/gray_scott
COPY CMakeLists.txt gray_scott.cu ./

RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCH} \
        -DHDF5_ROOT=/opt/hdf5 \
    && cmake --build build -j$(nproc)

ENV PATH=/opt/gray_scott/build:${PATH}

CMD ["/bin/bash"]
