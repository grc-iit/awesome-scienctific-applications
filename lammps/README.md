# LAMMPS — Large-scale Atomic/Molecular Massively Parallel Simulator

[LAMMPS](https://www.lammps.org/) is a classical molecular-dynamics code from
Sandia National Laboratories. This container builds the `develop` branch with
Kokkos CUDA support for GPU-accelerated force calculations.

---

## Prerequisites

- NVIDIA GPU (Ampere A100 = `CUDA_ARCH=80`, Hopper H100 = `90`, Volta V100 = `70`)
- Docker with NVIDIA Container Toolkit
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-lammps --build-arg CUDA_ARCH=80 .
```

---

## 2  Single-Node Run

The container ships the LAMMPS benchmark suite at `/opt/lammps/bench/`.

### Lennard-Jones fluid benchmark

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  sci-lammps \
  mpirun -np 4 --oversubscribe --allow-run-as-root \
    /opt/lammps/build/lmp \
    -k on g 1 -sf kk -pk kokkos cuda/aware on \
    -in /opt/lammps/bench/in.lj
```

### EAM metal benchmark

```bash
docker run --gpus all --rm sci-lammps \
  mpirun -np 4 --oversubscribe --allow-run-as-root \
    /opt/lammps/build/lmp \
    -k on g 1 -sf kk -pk kokkos cuda/aware on \
    -in /opt/lammps/bench/in.eam
```

### Key Kokkos/GPU flags

| Flag | Meaning |
|------|---------|
| `-k on g N` | Enable Kokkos with N GPUs |
| `-sf kk` | Append `/kk` suffix to all compatible pair/fix styles |
| `-pk kokkos cuda/aware on` | Enable CUDA-aware MPI (if supported by your MPI build) |

---

## 3  Multi-Node Run

Each node runs one container. Workers start an SSH daemon; the head node
launches `mpirun` with a host list.

### Worker nodes

```bash
# Run on each worker node (repeat with different --hostname values)
docker run --gpus all -d --rm \
  --hostname worker1 \
  --network host \
  --name lammps-worker1 \
  sci-lammps \
  /usr/sbin/sshd -D
```

### Head node

```bash
docker run --gpus all --rm \
  --network host \
  sci-lammps \
  mpirun -np 4 --allow-run-as-root \
    --host $(hostname):2,worker1.cluster.local:2 \
    /opt/lammps/build/lmp \
    -k on g 1 -sf kk -pk kokkos cuda/aware on \
    -in /opt/lammps/bench/in.lj
```

For larger runs scale `-np` and the host slot counts proportionally.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

Expected output ends with `Loop time of ...` and a performance summary.

### Validate multi-node

```bash
docker compose up -d worker1 worker2
sleep 3

docker compose exec head bash -c "
  mpirun -np 3 --allow-run-as-root \
    --host head:1,worker1:1,worker2:1 \
    /opt/lammps/build/lmp \
    -k on g 1 -sf kk -pk kokkos cuda/aware on \
    -in /opt/lammps/bench/in.lj
"

docker compose down
```
