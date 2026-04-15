# Xcompact3d — High-Order Finite-Difference Flow Solver

[Xcompact3d](https://github.com/xcompact3d/Incompact3d) is a Fortran-based
framework of high-order finite-difference flow solvers for turbulent flow
simulations (DNS/LES). This container builds Xcompact3d with the ADIOS2 IO
backend via the [2DECOMP&FFT](https://github.com/2decomp-fft/2decomp-fft)
parallel decomposition library.

---

## Prerequisites

- Docker or Podman

---

## 1  Build

```bash
docker build -t sci-xcompact3d .
```

The image is self-contained (based on `ubuntu:24.04`) and compiles three
components in order:

1. **ADIOS2 v2.10.2** — with MPI and Fortran support (BP4 engine, no HDF5 needed)
2. **2DECOMP&FFT v2.0.4** — with `IO_BACKEND=adios2`
3. **Incompact3d** — linked against pre-built 2DECOMP&FFT and ADIOS2

---

## 2  Single-Node Run

Xcompact3d uses `.i3d` namelist files as input. Several examples are included.

### Run the Taylor-Green Vortex (TGV)

```bash
docker run --rm \
  -v $(pwd)/run:/run \
  sci-xcompact3d \
  bash -c "
    mkdir -p /run/tgv && cd /run/tgv &&
    cp /opt/Incompact3d/examples/TGV-Taylor-Green-vortex/input.i3d . &&
    cp /opt/Incompact3d/examples/TGV-Taylor-Green-vortex/adios2_config.xml . &&
    mpirun -np 4 --oversubscribe --allow-run-as-root xcompact3d input.i3d
  "
```

### Available example cases

| Case | Input directory |
|------|----------------|
| Taylor-Green Vortex | `examples/TGV-Taylor-Green-vortex/` |
| Channel Flow | `examples/Channel/` |
| Cylinder Wake | `examples/Cylinder-wake/` |
| Mixing Layer | `examples/Mixing-layer/` |
| Periodic Hill | `examples/Periodic-hill/` |
| Gravity Current | `examples/Gravity-current/` |
| Atmospheric BL | `examples/ABL-Atmospheric-Boundary-Layer/` |
| Wind Turbine | `examples/Wind-Turbine/` |
| Pipe Flow | `examples/Pipe-Flow/` |

---

## 3  Multi-Node Run

### Start workers

```bash
# worker1.cluster.local
docker run -d --rm \
  --hostname worker1 --network host \
  -v $(pwd)/run:/run \
  --name x3d-worker1 sci-xcompact3d /usr/sbin/sshd -D

# worker2.cluster.local
docker run -d --rm \
  --hostname worker2 --network host \
  -v $(pwd)/run:/run \
  --name x3d-worker2 sci-xcompact3d /usr/sbin/sshd -D
```

### Run from head node

```bash
docker run --rm \
  --network host \
  -v $(pwd)/run:/run \
  sci-xcompact3d \
  bash -c "
    cd /run/tgv &&
    mpirun -np 6 --allow-run-as-root \
      --host \$(hostname):2,worker1.cluster.local:2,worker2.cluster.local:2 \
      xcompact3d input.i3d
  "
```

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

The `validate` service runs the TGV reference case with 2 MPI ranks.
Expected: Xcompact3d banner, followed by step-by-step time advancement output,
ending with `=== SINGLE-NODE TGV TEST PASSED ===`.

### Validate multi-node

```bash
docker compose up --abort-on-container-exit --exit-code-from head head
```

Runs 4 MPI ranks across 3 containers (head + 2 workers) via SSH.
