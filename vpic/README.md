# VPIC-Kokkos — Vector Particle-In-Cell Plasma Physics

[VPIC](https://github.com/lanl/vpic-kokkos) (Vector Particle-In-Cell) is an
explicit, relativistic, kinetic particle-in-cell code from Los Alamos National
Laboratory. This container builds the Kokkos-based GPU port with CUDA support.

VPIC uses an **input deck** model: you write a `.cxx` file describing the
simulation, the `vpic` tool compiles it into a standalone binary, and you run
that binary with MPI.

---

## Prerequisites

- NVIDIA GPU (Ampere A100 = `CUDA_ARCH=80`, Hopper H100 = `90`, Volta V100 = `70`)
- Docker with NVIDIA Container Toolkit
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-vpic --build-arg CUDA_ARCH=80 .
```

---

## 2  Single-Node Run

### Step 1 — Compile a deck

VPIC ships sample decks under `/opt/vpic-kokkos/sample/`. Compile one into a
binary:

```bash
docker run --gpus all --rm \
  -v $(pwd)/run:/run \
  sci-vpic \
  bash -c "
    cp /opt/vpic-kokkos/sample/harris/harris.cxx /run/ &&
    cd /run &&
    /opt/vpic-kokkos/build/vpic harris.cxx
  "
# Produces /run/harris.Linux
```

### Step 2 — Run the binary

```bash
docker run --gpus all --rm \
  -v $(pwd)/run:/run \
  sci-vpic \
  mpirun -np 4 --oversubscribe --allow-run-as-root /run/harris.Linux
```

### Available sample decks

| Deck | Physics |
|------|---------|
| `sample/harris/harris.cxx` | Harris current sheet (magnetic reconnection) |
| `sample/lpi/lpi.cxx` | Laser-plasma interaction |
| `sample/langmuir_wave/langmuir_wave.cxx` | 1D Langmuir wave |

---

## 3  Multi-Node Run

### Compile the deck first (on any node)

```bash
docker run --rm -v $(pwd)/run:/run sci-vpic \
  bash -c "cp /opt/vpic-kokkos/sample/harris/harris.cxx /run/ && \
            cd /run && /opt/vpic-kokkos/build/vpic harris.cxx"
```

### Start workers

```bash
# worker1.cluster.local
docker run --gpus all -d --rm \
  --hostname worker1 --network host \
  -v $(pwd)/run:/run \
  --name vpic-worker1 sci-vpic /usr/sbin/sshd -D

# worker2.cluster.local
docker run --gpus all -d --rm \
  --hostname worker2 --network host \
  -v $(pwd)/run:/run \
  --name vpic-worker2 sci-vpic /usr/sbin/sshd -D
```

### Run from head node

```bash
docker run --gpus all --rm \
  --network host \
  -v $(pwd)/run:/run \
  sci-vpic \
  mpirun -np 6 --allow-run-as-root \
    --host $(hostname):2,worker1.cluster.local:2,worker2.cluster.local:2 \
    /run/harris.Linux
```

VPIC tiles the domain across ranks automatically.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

The `validate` service compiles and runs the Harris deck with 2 MPI ranks.
Expected: VPIC version banner, followed by step-by-step diagnostics.

### Validate multi-node

```bash
docker compose up -d worker1 worker2
sleep 3

docker compose exec head bash -c "
  cp /opt/vpic-kokkos/sample/harris/harris.cxx /tmp/ &&
  cd /tmp &&
  /opt/vpic-kokkos/build/vpic harris.cxx &&
  mpirun -np 3 --allow-run-as-root \
    --host head:1,worker1:1,worker2:1 \
    /tmp/harris.Linux
"

docker compose down
```
