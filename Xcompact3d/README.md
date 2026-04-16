# Xcompact3d — High-Order Finite-Difference Flow Solver

[Xcompact3d](https://github.com/xcompact3d/Incompact3d) is a Fortran-based
framework of high-order finite-difference flow solvers for turbulent flow
simulations (DNS/LES). This container builds Xcompact3d with the ADIOS2 IO
backend via the [2DECOMP&FFT](https://github.com/2decomp-fft/2decomp-fft)
parallel decomposition library.

This README drives the container with
[Jarvis-CD](https://github.com/grc-iit/jarvis-cd). The Jarvis package lives
in `./InCompact3D/pkg.py` (class `Incompact3d`). It stages a benchmark
`input.i3d` and `adios2_config.xml` into a run directory and launches
`xcompact3d` under `mpirun` using the hosts in the active Jarvis hostfile.

```
Xcompact3d/
├── Dockerfile            # builds sci-xcompact3d (source build)
├── Dockerfile.deploy     # builds sci-xcompact3d-deploy (runtime-only)
├── docker-compose.yml    # simulated cluster (head + 2 workers)
├── adios2_config.xml     # BP5 ADIOS2 config baked into the image
├── InCompact3D/          # Jarvis package
│   ├── pkg.py            # class Incompact3d(Application)
│   ├── benchmarks/       # input.i3d templates (tgv, channel, pipe_flow, …)
│   └── config/           # adios2.xml / hermes.xml templates
└── README.md             # this file
```

---

## 1. Prerequisites

| Requirement | How to get it |
|-------------|---------------|
| `sci-xcompact3d` image (source build) | `docker build -t sci-xcompact3d -f Dockerfile .` |
| `sci-xcompact3d-deploy` image (runtime-only) | `docker build -t sci-xcompact3d-deploy -f Dockerfile.deploy .` |
| `jarvis-cd` + `jarvis-util` | `pip install git+https://github.com/grc-iit/jarvis-cd.git` inside the deploy container |

The source build compiles **ADIOS2 v2.10.2** (MPI + Fortran, BP5 engine),
**2DECOMP&FFT v2.0.4** (patched for BP5), and **Incompact3d v5.0**. The
`sci-xcompact3d-deploy` image is a thin runtime that copies pre-built
binaries from `sci-xcompact3d` — use it for single-node runs, multi-node
workers, and the simulated cluster validation below.

---

## 2. Run Single-Node in the Deployment Container

Drive a serial Taylor–Green Vortex (TGV) run with Jarvis inside a single
deploy container.

```bash
# Start an interactive deploy container with the pkg folder bind-mounted.
docker run --rm -it \
    --name xcompact3d-jarvis \
    -v "$(pwd)/InCompact3D":/jarvis-pkgs/InCompact3D \
    -v "$(pwd)/run":/run \
    sci-xcompact3d-deploy bash

# --- inside the container ---------------------------------------------
pip install --break-system-packages \
    git+https://github.com/grc-iit/jarvis-cd.git \
    git+https://github.com/grc-iit/jarvis-util.git

jarvis bootstrap from local                # single-host config
jarvis repo add /jarvis-pkgs/InCompact3D

# Build + run the Jarvis pipeline.
jarvis pipeline create xcompact3d_single
jarvis pipeline env build
jarvis pipeline append Incompact3d \
    benchmarks=tgv engine=bp5 \
    nprocs=2 ppn=2 \
    total_step=100 io_frequency=10 \
    output_location=/run/tgv
jarvis pipeline run

ls /run/tgv
```

`_configure` copies `InCompact3D/benchmarks/tgv/input.i3d` and
`InCompact3D/config/adios2.xml` into `output_location` (substituting
`total_step` and `io_frequency`), and `start` `cwd`s into that directory
before launching `xcompact3d` under `mpirun`. `jarvis pipeline clean`
removes `data.bp5`, the config, and the staged `input.i3d`.

### Available benchmarks

| `benchmarks=` | Case | Template |
|---------------|------|----------|
| `tgv` | Taylor–Green Vortex | `InCompact3D/benchmarks/tgv/input.i3d` |
| `channel` | Channel flow | `InCompact3D/benchmarks/channel/input.i3d` |
| `cylinder` | Cylinder wake | `InCompact3D/benchmarks/cylinder/input.i3d` |
| `mixing_layer` | Mixing layer | `InCompact3D/benchmarks/mixing_layer/input.i3d` |
| `periodic` | Periodic hill | `InCompact3D/benchmarks/periodic/input.i3d` |
| `pipe_flow` | Pipe flow | `InCompact3D/benchmarks/pipe_flow/input.i3d` |
| `abl` | Atmospheric boundary layer | `InCompact3D/benchmarks/abl/input.i3d` |
| `cavity` | Lid-driven cavity | `InCompact3D/benchmarks/cavity/input.i3d` |
| `tbl` | Turbulent boundary layer | `InCompact3D/benchmarks/tbl/input.i3d` |
| `mdh` | Magnetohydrodynamics | `InCompact3D/benchmarks/mdh/input.i3d` |
| `partical` | Particle-laden | `InCompact3D/benchmarks/partical/input.i3d` |

---

## 3. Distribute the Deploy Container Across Nodes

The same deploy image doubles as a worker by running `sshd`. The head
container drives Jarvis and lets `mpirun` reach the workers over SSH
using the hostfile Jarvis owns. SSH host keys are baked into the image,
so all containers trust each other out-of-the-box.

### 3.1 Launch workers on each physical host

```bash
# --- on node worker1 -------------------------------------------------
docker run -d --rm \
    --hostname worker1 --network host \
    -v $(pwd)/run:/run \
    --name xcompact3d-worker1 sci-xcompact3d-deploy /usr/sbin/sshd -D

# --- on node worker2 -------------------------------------------------
docker run -d --rm \
    --hostname worker2 --network host \
    -v $(pwd)/run:/run \
    --name xcompact3d-worker2 sci-xcompact3d-deploy /usr/sbin/sshd -D
```

`/run/` must be a **shared** path visible on every node (NFS, Lustre,
cloud FUSE mount, etc.) — every MPI rank reads the same staged
`input.i3d` + `adios2_config.xml` the head prepared, and writes the
shared `data.bp5` ADIOS2 dataset.

### 3.2 Start the head and drive Jarvis

```bash
# --- on the head node ------------------------------------------------
docker run --rm -it \
    --hostname head --network host \
    -v $(pwd)/run:/run \
    -v $(pwd)/InCompact3D:/jarvis-pkgs/InCompact3D \
    --name xcompact3d-head sci-xcompact3d-deploy bash

# --- inside head -----------------------------------------------------
pip install --break-system-packages \
    git+https://github.com/grc-iit/jarvis-cd.git \
    git+https://github.com/grc-iit/jarvis-util.git

cat > /etc/hostfile <<EOF
head
worker1
worker2
EOF
jarvis bootstrap from local
jarvis hostfile set /etc/hostfile
jarvis repo add /jarvis-pkgs/InCompact3D

# Build + run the Jarvis pipeline across 3 nodes, 2 ranks each.
jarvis pipeline create xcompact3d_multi
jarvis pipeline env build
jarvis pipeline append Incompact3d \
    benchmarks=tgv engine=bp5 \
    nprocs=6 ppn=2 \
    total_step=100 io_frequency=10 \
    output_location=/run/tgv
jarvis pipeline run
```

`Incompact3d.start` forwards `self.jarvis.hostfile` to `MpiExecInfo`, so
Jarvis fans the 6 ranks out over the three containers. 2DECOMP&FFT
auto-decomposes the domain to match `nprocs`.

> **TCP interface note:** `pkg.py` currently hardcodes
> `OMPI_MCA_btl_tcp_if_include=eno1` and `OMPI_MCA_oob_tcp_if_include=eno1`.
> If your physical nodes expose a different NIC, edit `InCompact3D/pkg.py`
> (the `start` method) to set the correct interface name — otherwise
> OpenMPI will fail to bootstrap across nodes.

---

## 4. Simulated Docker Cluster (Validation)

The `docker-compose.yml` in this directory brings up a head + two worker
cluster on a single physical host so you can validate sections 2 and 3
end-to-end without any real multi-node hardware. The existing `validate`
and `head`/`worker1`/`worker2` services cover the raw `mpirun` path;
append the **Jarvis-driven** service below to `docker-compose.yml` under
the existing `services:` block to validate the Jarvis flow.

```yaml
  jarvis-validate:
    image: sci-xcompact3d-deploy:latest
    hostname: jarvis-head
    depends_on:
      worker1:
        condition: service_healthy
      worker2:
        condition: service_healthy
    volumes:
      - output:/output
      - ./InCompact3D:/jarvis-pkgs/InCompact3D:ro
    networks:
      - mpi-net
    command:
      - bash
      - -c
      - |
        set -e
        /usr/sbin/sshd

        # 1. Install Jarvis inside the head container.
        pip install --break-system-packages --quiet \
            git+https://github.com/grc-iit/jarvis-cd.git \
            git+https://github.com/grc-iit/jarvis-util.git

        # 2. Describe the simulated cluster to Jarvis.
        cat > /etc/hostfile <<EOF
        jarvis-head
        worker1
        worker2
        EOF
        jarvis bootstrap from local
        jarvis hostfile set /etc/hostfile
        jarvis repo add /jarvis-pkgs/InCompact3D

        # 3. The compose mpi-net bridge is eth0, not eno1 — patch the
        #    hardcoded interface name in pkg.py for this run.
        sed -i "s/'eno1'/'eth0'/g" /jarvis-pkgs/InCompact3D/pkg.py

        # 4. Build + run the Jarvis pipeline across the 3 containers.
        jarvis pipeline create xcompact3d_ci
        jarvis pipeline env build
        jarvis pipeline append Incompact3d \
            benchmarks=tgv engine=bp5 \
            nprocs=4 ppn=2 \
            total_step=10 io_frequency=10 \
            output_location=/output/tgv
        jarvis pipeline run

        test -s /output/tgv/input.i3d \
          && echo '=== JARVIS CLUSTER TEST PASSED ==='
```

The existing `worker1`/`worker2` services already run `sshd -D`, share
the `output` volume, and live on the `mpi-net` bridge — they satisfy
everything this service needs. The `sed` step adapts the Jarvis pkg's
hardcoded `eno1` NIC to the compose bridge's `eth0` interface; drop it
once `pkg.py` is parameterised.

### Run the validation

```bash
# Raw single-node / multi-node checks (no Jarvis).
docker compose run --rm validate                        # section 2 raw
docker compose up --abort-on-container-exit \
                 --exit-code-from head head             # section 3 raw

# Jarvis-driven check.
docker compose up --abort-on-container-exit \
                 --exit-code-from jarvis-validate \
                 jarvis-validate
```

A passing Jarvis run ends with:

```
=== JARVIS CLUSTER TEST PASSED ===
```

Clean up:

```bash
docker compose down -v
```

---

## 5. Package Configuration Reference

Options exposed by `InCompact3D/pkg.py`:

| Option | Default | Description |
|--------|---------|-------------|
| `nprocs` | `1` | Total MPI ranks passed to `mpirun -np`. |
| `ppn` | `16` | Ranks per node; paired with Jarvis's hostfile. |
| `engine` | `bp5` | ADIOS2 engine — `bp5` or `hermes`. Selects which XML template is staged. |
| `benchmarks` | `tgv` | Benchmark case; picks which `input.i3d` template under `benchmarks/` is staged. |
| `total_step` | `1000` | Total simulation time steps (substituted into `input.i3d`). |
| `io_frequency` | `1` | Steps between I/O snapshots (substituted into `input.i3d`). |
| `output_location` | `output` | Run directory; `_configure` creates it and `start` `cwd`s into it. |
| `db_path` | `benchmark_metadata.db` | Metadata DB path (used by the Hermes engine). |
| `logs` | `logs.txt` | Log file path. |

Lifecycle: `_configure` stages `adios2_config.xml` + `input.i3d` into
`output_location`; `start` runs `xcompact3d` under
`MpiExecInfo(nprocs, ppn, hostfile, cwd=output_location)`; `clean`
removes `data.bp5`, the staged XML/input, and the metadata DB via
`pssh` across the hostfile.

---

## 6. Installed Software

| Component | Version | Location |
|-----------|---------|----------|
| ADIOS2 | 2.10.2 (MPI + Fortran, BP5) | `/opt/adios2` |
| 2DECOMP&FFT | 2.0.4 (patched for BP5) | `/opt/2decomp-fft` |
| Incompact3d | 5.0 | `/opt/Incompact3d` |
| OpenMPI | system | ubuntu:24.04 |

---

## 7. References

- Jarvis-CD: <https://github.com/grc-iit/jarvis-cd>
- Jarvis-CD docs: <https://grc.iit.edu/docs/jarvis/jarvis-cd/index>
- Upstream Xcompact3d: <https://github.com/xcompact3d/Incompact3d>
- 2DECOMP&FFT: <https://github.com/2decomp-fft/2decomp-fft>
- ADIOS2: <https://github.com/ornladios/ADIOS2>
