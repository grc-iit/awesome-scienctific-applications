# OpenFOAM-dev — Computational Fluid Dynamics

[OpenFOAM](https://github.com/OpenFOAM/OpenFOAM-dev) (Open Field Operation
And Manipulation) is an open-source CFD framework from the OpenFOAM Foundation.
This container builds OpenFOAM-dev from source with system MPI and installs
ADIOS2 for high-performance I/O in coupled workflows.

This README drives the container with [Jarvis-CD](https://github.com/grc-iit/jarvis-cd).
The Jarvis package lives in `./openfoam/pkg.py` (class `Openfoam`) and runs
the `Allrun` script of any OpenFOAM case directory under MPI using the hosts
in the active Jarvis hostfile.

```
openfoam/
├── Dockerfile            # builds sci-openfoam (source build)
├── Dockerfile.deploy     # builds sci-openfoam-deploy (runtime-only)
├── docker-compose.yml    # simulated cluster (head + 2 workers)
├── openfoam/
│   ├── pkg.py            # Jarvis Application definition
│   └── README.md
└── README.md             # this file
```

> **Note:** OpenFOAM-dev (openfoam.org) does not include native ADIOS2
> integration. ADIOS2 is installed alongside OpenFOAM and is available for
> custom function objects, in-situ analysis, or coupled workflow pipelines.

---

## 1. Prerequisites

| Requirement | How to get it |
|-------------|---------------|
| `sci-hpc-base` image | `docker build -t sci-hpc-base ../base` |
| `sci-openfoam` image (source build) | `docker build -t sci-openfoam -f Dockerfile .` |
| `sci-openfoam-deploy` image (runtime-only) | `docker build -t sci-openfoam-deploy -f Dockerfile.deploy .` |
| `jarvis-cd` + `jarvis-util` | `pip install git+https://github.com/grc-iit/jarvis-cd.git` inside the deploy container |

The `sci-openfoam` build compiles ~400+ libraries and solvers and takes a
while. The `sci-openfoam-deploy` image is a thin runtime that copies
pre-built binaries from `sci-openfoam` — use it for single-node runs,
multi-node workers, and the simulated cluster validation below.

---

## 2. Run Single-Node in the Deployment Container

Drive a serial run of the built-in lid-driven `cavity` tutorial with Jarvis
inside a single deploy container.

```bash
# Start an interactive deploy container with the pkg folder bind-mounted.
docker run --rm -it \
    --name openfoam-jarvis \
    -v "$(pwd)":/jarvis-pkgs/openfoam \
    -v "$(pwd)/run":/run \
    sci-openfoam-deploy bash

# --- inside the container ---------------------------------------------
pip install --break-system-packages \
    git+https://github.com/grc-iit/jarvis-cd.git \
    git+https://github.com/grc-iit/jarvis-util.git

jarvis bootstrap from local              # single-host config
jarvis repo add /jarvis-pkgs/openfoam

# Stage a tutorial case into the bind-mounted run directory.
source /opt/OpenFOAM/OpenFOAM-dev/etc/bashrc
cp -r "$FOAM_TUTORIALS/incompressibleFluid/cavity" /run/cavity

# Build + run the Jarvis pipeline.
jarvis pipeline create openfoam_single
jarvis pipeline env build
jarvis pipeline append openfoam \
    nprocs=1 ppn=1 \
    script_location=/run/cavity
jarvis pipeline run

ls /run/cavity/[0-9]*
```

The `Openfoam` pkg `cwd`s into `script_location` and executes the case's
`Allrun` script under `mpirun`. Tutorial `Allrun` scripts call
`blockMesh`, run the solver, and write time-step directories (`0.1`,
`0.2`, …). `jarvis pipeline clean` tears down the pipeline metadata.

### Available tutorial cases

| Case | Physics |
|------|---------|
| `incompressibleFluid/cavity` | Lid-driven cavity (laminar) |
| `incompressibleFluid/pitzDaily` | Backward-facing step (turbulent) |
| `incompressibleFluid/elbow` | Pipe elbow flow |
| `compressibleFluid/shockTube` | Sod shock tube |
| `multicomponentFluid/aachenBomb` | Spray combustion |

Full tutorial list: `/opt/OpenFOAM/OpenFOAM-dev/tutorials/`.

---

## 3. Distribute the Deploy Container Across Nodes

The same deploy image doubles as a worker by running `sshd`. The head
container drives Jarvis and lets `mpirun` reach the workers over SSH
using the hostfile that Jarvis owns.

### 3.1 Launch workers on each physical host

```bash
# --- on node worker1 -------------------------------------------------
docker run -d --rm \
    --hostname worker1 --network host \
    -v $(pwd)/run:/run \
    --name openfoam-worker1 sci-openfoam-deploy /usr/sbin/sshd -D

# --- on node worker2 -------------------------------------------------
docker run -d --rm \
    --hostname worker2 --network host \
    -v $(pwd)/run:/run \
    --name openfoam-worker2 sci-openfoam-deploy /usr/sbin/sshd -D
```

`/run/` must be a **shared** path visible on every node (NFS, Lustre,
cloud FUSE mount, etc.) — every MPI rank reads the same decomposed
domain files the head prepared.

### 3.2 Start the head and drive Jarvis

```bash
# --- on the head node ------------------------------------------------
docker run --rm -it \
    --hostname head --network host \
    -v $(pwd)/run:/run \
    -v $(pwd):/jarvis-pkgs/openfoam \
    --name openfoam-head sci-openfoam-deploy bash

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
jarvis repo add /jarvis-pkgs/openfoam

# Stage + decompose the cavity case on the shared volume.
source /opt/OpenFOAM/OpenFOAM-dev/etc/bashrc
cp -r "$FOAM_TUTORIALS/incompressibleFluid/cavity" /run/cavity
cd /run/cavity
blockMesh
cat > system/decomposeParDict <<'DICT'
FoamFile { format ascii; class dictionary; object decomposeParDict; }
numberOfSubdomains 6;
method simple;
simpleCoeffs { n (3 2 1); }
DICT
decomposePar

# Build + run the Jarvis pipeline across 3 nodes, 2 ranks each.
jarvis pipeline create openfoam_multi
jarvis pipeline env build
jarvis pipeline append openfoam \
    nprocs=6 ppn=2 \
    script_location=/run/cavity
jarvis pipeline run
```

The `Openfoam` pkg forwards `self.jarvis.hostfile` to `MpiExecInfo`, so
Jarvis fans the 6 ranks out over the three containers; OpenFOAM's
`decomposePar` split the mesh into matching subdomains. When you run
your own case instead of `cavity`, point `script_location` at the case
directory whose `Allrun` (or equivalent) orchestrates the parallel
solver call (`foamRun -parallel`).

---

## 4. Simulated Docker Cluster (Validation)

The `docker-compose.yml` in this directory brings up a head + two
worker cluster on a single physical host so you can validate sections
2 and 3 end-to-end without any real multi-node hardware. The existing
`validate` and `head`/`worker1`/`worker2` services cover the raw
`mpirun` path; append the **Jarvis-driven** service below to
`docker-compose.yml` under the existing `services:` block to validate
the Jarvis flow.

```yaml
  jarvis-validate:
    image: sci-openfoam-deploy:latest
    hostname: jarvis-head
    depends_on:
      worker1:
        condition: service_healthy
      worker2:
        condition: service_healthy
    volumes:
      - output:/output
      - ./openfoam:/jarvis-pkgs/openfoam/openfoam:ro   # mount the pkg
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
        jarvis repo add /jarvis-pkgs/openfoam

        # 3. Stage + decompose the cavity tutorial on the shared volume.
        source /opt/OpenFOAM/OpenFOAM-dev/etc/bashrc
        mkdir -p /output
        cp -r "$$FOAM_TUTORIALS/incompressibleFluid/cavity" /output/cavity
        cd /output/cavity
        blockMesh
        cat > system/decomposeParDict <<'DICT'
        FoamFile { format ascii; class dictionary; object decomposeParDict; }
        numberOfSubdomains 3;
        method simple;
        simpleCoeffs { n (3 1 1); }
        DICT
        decomposePar

        # 4. Build + run the Jarvis pipeline across the 3 containers.
        jarvis pipeline create openfoam_ci
        jarvis pipeline env build
        jarvis pipeline append openfoam \
            nprocs=3 ppn=1 \
            script_location=/output/cavity
        jarvis pipeline run

        ls /output/cavity/processor0/0.1 \
          && echo '=== JARVIS CLUSTER TEST PASSED ==='
```

The existing `worker1`/`worker2` services already run `sshd -D`, share
the `output` volume, and live on the `mpi-net` bridge — they satisfy
everything this service needs. If your tutorial case does not ship an
`Allrun` script that supports parallel execution, point the pkg at a
bespoke `Allrun` that invokes `foamRun -parallel` after `decomposePar`.

### Run the validation

```bash
# Bring up the raw single-node / multi-node checks first.
docker compose run --rm validate                        # section 2 raw
docker compose up --abort-on-container-exit \
                 --exit-code-from head head             # section 3 raw

# Then the Jarvis-driven check.
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

Options exposed by `openfoam/pkg.py`:

| Option | Default | Description |
|--------|---------|-------------|
| `nprocs` | `1` | Total MPI ranks passed to `mpirun -np`. |
| `ppn` | `4` | Ranks per node; paired with Jarvis's hostfile. |
| `script_location` | `None` | Case directory containing an `Allrun` script; pkg `cwd`s here before launching. |

Lifecycle: `_configure` stores the CLI parameters; `start` runs
`./Allrun` under `MpiExecInfo(nprocs, ppn, hostfile, cwd)`; `stop` and
`clean` are no-ops (remove case output manually if desired).

---

## 6. Installed Software

| Component | Version | Location |
|-----------|---------|----------|
| OpenFOAM | dev (latest) | `/opt/OpenFOAM/OpenFOAM-dev` |
| ThirdParty | dev (Scotch, etc.) | `/opt/OpenFOAM/ThirdParty-dev` |
| ADIOS2 | 2.10.2 | `/opt/adios2` |
| HDF5 | 2.0.0 (parallel) | `/opt/hdf5` |
| OpenMPI | system | via base image |

---

## 7. References

- Jarvis-CD: <https://github.com/grc-iit/jarvis-cd>
- Jarvis-CD docs: <https://grc.iit.edu/docs/jarvis/jarvis-cd/index>
- Upstream OpenFOAM-dev: <https://github.com/OpenFOAM/OpenFOAM-dev>
- ADIOS2: <https://github.com/ornladios/ADIOS2>
