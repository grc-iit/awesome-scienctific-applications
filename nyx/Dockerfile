# Nyx cosmological simulation (AMReX-based)
# Builds the HydroTests target (Sedov blast + cosmological hydro tests).
# Vanilla Nyx — no external compression libraries.
#
# Build:
#   docker build -t sci-nyx --build-arg CUDA_ARCH=80 .

FROM sci-hpc-base

ARG CUDA_ARCH=80

# Clone Nyx with AMReX submodule, pin AMReX to development branch
RUN git clone --recursive https://github.com/AMReX-Astro/Nyx.git /opt/Nyx \
    && cd /opt/Nyx/subprojects/amrex && git checkout development

# Build Nyx HydroTests — single precision, CUDA, MPI, HDF5
RUN cd /opt/Nyx \
    && cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DNyx_MPI=YES \
        -DNyx_OMP=NO \
        -DNyx_HYDRO=YES \
        -DNyx_HEATCOOL=NO \
        -DAMReX_HDF5=YES \
        -DHDF5_ROOT=/opt/hdf5 \
        -DNyx_GPU_BACKEND=CUDA \
        -DAMReX_CUDA_ARCH=${CUDA_ARCH} \
        -DAMReX_PRECISION=SINGLE \
        -DAMReX_PARTICLES_PRECISION=SINGLE \
        -DCMAKE_C_COMPILER="$(which gcc)" \
        -DCMAKE_CXX_COMPILER="$(which g++)" \
        -DCMAKE_CUDA_HOST_COMPILER="$(which g++)" \
    && cmake --build build --target nyx_HydroTests -j$(nproc)

ENV PATH=/opt/Nyx/build/Exec/HydroTests:${PATH}

CMD ["/bin/bash"]
