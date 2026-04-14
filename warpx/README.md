# WarpX — Exascale Particle-In-Cell Plasma Accelerator Simulation

[WarpX](https://ecp-warpx.github.io/) is a highly parallel, GPU-optimized
Particle-In-Cell (PIC) code built on AMReX. It targets plasma accelerator and
beam-physics problems. This container builds the 3D CUDA configuration with
MPI and HDF5 output enabled.

---

## Prerequisites

- NVIDIA GPU (Ampere A100 = `CUDA_ARCH=80`, Hopper H100 = `90`, Volta V100 = `70`)
- Docker with NVIDIA Container Toolkit
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-warpx --build-arg CUDA_ARCH=80 .
```

---

## 2  Single-Node Run

WarpX reads problem parameters from an **inputs file**. The container ships
example inputs under `/opt/warpx/Examples/`.

### Laser acceleration (quick test)

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  -w /opt/warpx/Examples/Physics_applications/laser_acceleration \
  sci-warpx \
  mpirun -np 2 --oversubscribe --allow-run-as-root \
    /opt/warpx/build/bin/warpx.3d.MPI.CUDA.SP \
    inputs_base_3d \
    max_step=50 \
    amr.n_cell=64 64 128 \
    amr.plot_file=/output/plt \
    amr.plot_int=10
```

### Uniform plasma (larger run)

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  -w /opt/warpx/Examples/Physics_applications/uniform_plasma \
  sci-warpx \
  mpirun -np 4 --oversubscribe --allow-run-as-root \
    /opt/warpx/build/bin/warpx.3d.MPI.CUDA.SP \
    inputs_3d \
    max_step=100 \
    amr.n_cell=128 128 128
```

### Key ParmParse parameters

| Key | Description |
|-----|-------------|
| `max_step` | Total number of time steps |
| `amr.n_cell` | Base grid cells (x y z) |
| `amr.max_level` | AMR refinement levels |
| `amr.plot_file` | Output file prefix |
| `amr.plot_int` | Plot interval (-1 = off) |
| `warpx.serialize_initial_conditions` | Reproducible init (debugging) |

---

## 3  Multi-Node Run

### Start workers

```bash
docker run --gpus all -d --rm \
  --hostname worker1 --network host \
  --name warpx-worker1 sci-warpx /usr/sbin/sshd -D

docker run --gpus all -d --rm \
  --hostname worker2 --network host \
  --name warpx-worker2 sci-warpx /usr/sbin/sshd -D
```

### Run from head node

```bash
docker run --gpus all --rm \
  --network host \
  -v $(pwd)/output:/output \
  -w /opt/warpx/Examples/Physics_applications/laser_acceleration \
  sci-warpx \
  mpirun -np 6 --allow-run-as-root \
    --host $(hostname):2,worker1.cluster.local:2,worker2.cluster.local:2 \
    /opt/warpx/build/bin/warpx.3d.MPI.CUDA.SP \
    inputs_base_3d \
    max_step=200 \
    amr.n_cell=128 128 256 \
    amr.max_level=1 \
    amr.plot_file=/output/plt \
    amr.plot_int=20
```

AMReX automatically distributes the grid across all MPI ranks.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

Expected: AMReX + WarpX banner, 10 time steps, and final step summary.

### Validate multi-node

```bash
docker compose up -d worker1 worker2
sleep 3

docker compose exec head bash -c "
  cd /opt/warpx/Examples/Physics_applications/laser_acceleration &&
  mpirun -np 3 --allow-run-as-root \
    --host head:1,worker1:1,worker2:1 \
    /opt/warpx/build/bin/warpx.3d.MPI.CUDA.SP \
    inputs_base_3d \
    max_step=10 \
    amr.n_cell=32 32 64
"

docker compose down
```
