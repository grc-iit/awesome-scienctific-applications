# Nyx — AMReX Cosmological Simulation

[Nyx](https://amrex-astro.github.io/Nyx/) is an adaptive mesh, massively
parallel cosmological simulation code built on the AMReX framework. This
container builds the HydroTests target (Sedov blast wave and hydro unit tests)
with CUDA, MPI, and HDF5 output enabled.

---

## Prerequisites

- NVIDIA GPU (Ampere A100 = `CUDA_ARCH=80`, Hopper H100 = `90`, Volta V100 = `70`)
- Docker with NVIDIA Container Toolkit
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-nyx --build-arg CUDA_ARCH=80 .
```

---

## 2  Single-Node Run

The HydroTests executable accepts AMReX ParmParse key=value arguments directly
on the command line or via an input file.

### Quick smoke test (32³ grid, 10 steps)

```bash
docker run --gpus all --rm sci-nyx \
  mpirun -np 2 --oversubscribe --allow-run-as-root \
    /opt/Nyx/build/Exec/HydroTests/nyx_HydroTests \
    max_step=10 amr.n_cell=32 32 32
```

### Full Sedov blast wave (128³ grid, with HDF5 output)

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  sci-nyx \
  mpirun -np 4 --oversubscribe --allow-run-as-root \
    /opt/Nyx/build/Exec/HydroTests/nyx_HydroTests \
    max_step=100 \
    amr.n_cell=128 128 128 \
    amr.plot_file=/output/plt \
    amr.plot_int=10
```

### Common ParmParse keys

| Key | Default | Description |
|-----|---------|-------------|
| `max_step` | — | Number of coarse time steps |
| `amr.n_cell` | — | Base grid cells per dimension |
| `amr.max_level` | 0 | Maximum AMR refinement level |
| `amr.plot_file` | `plt` | Output file prefix |
| `amr.plot_int` | -1 | Plot file interval (-1 = off) |

---

## 3  Multi-Node Run

### Start workers

```bash
# worker1.cluster.local
docker run --gpus all -d --rm \
  --hostname worker1 --network host \
  --name nyx-worker1 sci-nyx /usr/sbin/sshd -D

# worker2.cluster.local
docker run --gpus all -d --rm \
  --hostname worker2 --network host \
  --name nyx-worker2 sci-nyx /usr/sbin/sshd -D
```

### Run from head node

```bash
docker run --gpus all --rm \
  --network host \
  -v $(pwd)/output:/output \
  sci-nyx \
  mpirun -np 6 --allow-run-as-root \
    --host $(hostname):2,worker1.cluster.local:2,worker2.cluster.local:2 \
    /opt/Nyx/build/Exec/HydroTests/nyx_HydroTests \
    max_step=200 \
    amr.n_cell=256 256 256 \
    amr.max_level=1 \
    amr.plot_file=/output/plt \
    amr.plot_int=20
```

AMReX automatically distributes boxes across MPI ranks; no user-level domain
decomposition is required.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

Expected: AMReX banner, grid summary, and `nyx_HydroTests: All tests passed.`
(or equivalent step output).

### Validate multi-node

```bash
docker compose up -d worker1 worker2
sleep 3

docker compose exec head bash -c "
  mpirun -np 3 --allow-run-as-root \
    --host head:1,worker1:1,worker2:1 \
    /opt/Nyx/build/Exec/HydroTests/nyx_HydroTests \
    max_step=10 amr.n_cell=32 32 32
"

docker compose down
```
