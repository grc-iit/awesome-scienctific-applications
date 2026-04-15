# Shared base image for scientific HPC applications
# Provides: CUDA 12.6, OpenMPI, parallel HDF5 2.0.0, SSH for MPI multi-node
#
# Build:
#   docker build -t sci-hpc-base .
#
# NOTE: The SSH key baked into this image is for simulation/development clusters only.
#       Do not use this image in production without replacing the SSH keys.

FROM nvidia/cuda:12.6.0-devel-ubuntu24.04

ARG CUDA_ARCH=80

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake curl wget git python3 python3-pip \
    openmpi-bin libopenmpi-dev \
    openssh-server openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Parallel HDF5 2.0.0
RUN curl -L -o /tmp/hdf5.tar.gz \
    "https://github.com/HDFGroup/hdf5/releases/download/2.0.0/hdf5-2.0.0.tar.gz" \
    && cd /tmp && tar xzf hdf5.tar.gz --no-same-owner --no-same-permissions \
    && mkdir hdf5-build && cd hdf5-build \
    && cmake /tmp/hdf5-2.0.0 \
        -DCMAKE_INSTALL_PREFIX=/opt/hdf5 \
        -DCMAKE_BUILD_TYPE=Release \
        -DHDF5_ENABLE_PARALLEL=ON \
        -DHDF5_BUILD_TOOLS=OFF \
        -DHDF5_BUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
        -DHDF5_BUILD_CPP_LIB=OFF \
        -DHDF5_BUILD_FORTRAN=OFF \
        -DHDF5_BUILD_JAVA=OFF \
        -DHDF5_BUILD_HL_LIB=ON \
    && make -j$(nproc) && make install \
    && rm -rf /tmp/hdf5.tar.gz /tmp/hdf5-2.0.0 /tmp/hdf5-build

ENV HDF5_ROOT=/opt/hdf5
ENV LD_LIBRARY_PATH=/opt/hdf5/lib:${LD_LIBRARY_PATH}

# SSH setup for MPI multi-node (simulation only — same key across all derived containers)
RUN mkdir -p /var/run/sshd /root/.ssh \
    && ssh-keygen -A \
    && ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 \
    && cat /root/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys \
    && chmod 700 /root/.ssh \
    && chmod 600 /root/.ssh/authorized_keys \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && printf "StrictHostKeyChecking no\nUserKnownHostsFile /dev/null\n" >> /etc/ssh/ssh_config

EXPOSE 22
CMD ["/bin/bash"]
