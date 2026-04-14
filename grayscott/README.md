# Gray-Scott Reaction-Diffusion

A GPU-accelerated MPI+CUDA simulation of the Gray-Scott reaction-diffusion system:

```
du/dt = Du·∇²u − u·v² + F·(1 − u)
dv/dt = Dv·∇²v + u·v² − (F+k)·v
```

The domain is decomposed row-wise across MPI ranks; each rank owns a horizontal
slab and exchanges one ghost row per side each step. Output is written to HDF5
files named `gs_NNNNNN.h5`.

---

## Prerequisites

- NVIDIA GPU (Ampere A100 = `CUDA_ARCH=80`, Hopper H100 = `90`, Volta V100 = `70`)
- Docker with NVIDIA Container Toolkit
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
# Build the base image (once, shared by all apps)
docker build -t sci-hpc-base ../base

# Build this image
docker build -t sci-grayscott --build-arg CUDA_ARCH=80 .
```

---

## 2  Single-Node Run

Run the simulation with 4 MPI ranks on one GPU (using `--oversubscribe` so that
all 4 ranks share the single GPU):

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  sci-grayscott \
  mpirun -np 4 --oversubscribe --allow-run-as-root \
    /opt/gray_scott/build/gray_scott \
    --width 512 --height 512 \
    --steps 5000 --out-every 500 \
    --outdir /output
```

### Common parameters

| Flag | Default | Description |
|------|---------|-------------|
| `--width N` | 512 | Global grid width (columns) |
| `--height N` | 512 | Global grid height (rows) |
| `--steps N` | 5000 | Total time steps |
| `--out-every N` | 500 | HDF5 output interval |
| `--outdir PATH` | `.` | Output directory |
| `--F val` | 0.035 | Feed rate |
| `--k val` | 0.060 | Kill rate |
| `--Du val` | 0.16 | Diffusion coefficient (u) |
| `--Dv val` | 0.08 | Diffusion coefficient (v) |

---

## 3  Multi-Node Run

Each physical node runs one container. The base image pre-bakes an SSH key pair
so containers derived from the same image can SSH into each other without a
password (suitable for development/simulation clusters only).

### Start worker containers

On **worker node 1** (`worker1.cluster.local`):
```bash
docker run --gpus all -d --rm \
  --hostname worker1 \
  --network host \
  --name gs-worker1 \
  sci-grayscott \
  /usr/sbin/sshd -D
```

On **worker node 2** (`worker2.cluster.local`):
```bash
docker run --gpus all -d --rm \
  --hostname worker2 \
  --network host \
  --name gs-worker2 \
  sci-grayscott \
  /usr/sbin/sshd -D
```

### Run from the head node

```bash
docker run --gpus all --rm \
  --network host \
  -v $(pwd)/output:/output \
  sci-grayscott \
  mpirun -np 3 --allow-run-as-root \
    --host $(hostname):1,worker1.cluster.local:1,worker2.cluster.local:1 \
    /opt/gray_scott/build/gray_scott \
    --width 1024 --height 1024 \
    --steps 5000 --out-every 500 \
    --outdir /output
```

Each rank is assigned `GH / nranks` rows of the global grid; the last rank
absorbs any remainder.

---

## 4  Simulated Cluster Validation

`docker-compose.yml` contains a ready-made cluster that validates both the
single-node and multi-node instructions.

### Validate single-node (4 ranks, 1 container)

```bash
docker compose run --rm validate
```

Expected output:
```
Gray-Scott 256x256  4 ranks  200 steps
  wrote /output/gs_000100.h5
  wrote /output/gs_000200.h5
Done.
```

### Validate multi-node (3 ranks across head + 2 workers)

```bash
# Start workers in background
docker compose up -d worker1 worker2

# Wait for SSH daemons to be ready
sleep 3

# Launch job from head container
docker compose exec head bash -c "
  mpirun -np 3 --allow-run-as-root \
    --host head:1,worker1:1,worker2:1 \
    /opt/gray_scott/build/gray_scott \
    --width 256 --height 256 --steps 200 --out-every 100 --outdir /output
"

# Tear down
docker compose down -v
```

Expected output across the three containers:
```
Gray-Scott 256x256  3 ranks  200 steps
  wrote /output/gs_000100.h5
  wrote /output/gs_000200.h5
Done.
```
