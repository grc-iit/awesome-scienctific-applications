# WRF — Weather Research and Forecasting Model

[WRF](https://github.com/wrf-model/WRF) is a next-generation mesoscale numerical
weather prediction system developed by NCAR, NOAA, and partners. This container
builds WRF v4.6.0 with **parallel HDF5**, **ADIOS2**, and **NetCDF** I/O support,
plus the **WPS** preprocessing system.

WRF is CPU-only (MPI parallelism). The CUDA layer in the base image is inherited
but unused by WRF itself.

---

## Prerequisites

- Docker or Podman
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-wrf .
```

Optionally build a lighter deploy image (skips recompilation):

```bash
docker build -t sci-wrf-deploy -f Dockerfile.deploy .
```

The WRF compile takes a while (~30 min with 40 cores). The image includes:

| Library | Version | Location |
|---------|---------|----------|
| HDF5 (parallel, Fortran) | 2.0.0 | `/opt/hdf5` (rebuilt with zlib + szip + Fortran) |
| NetCDF-C | 4.9.2 | `/opt/netcdf` |
| NetCDF-Fortran | 4.6.1 | `/opt/netcdf` |
| ADIOS2 | 2.10.2 | `/opt/adios2` |
| JasPer | 4.2.4 | `/opt/jasper` |

### WRF executables

| Binary | Purpose |
|--------|---------|
| `wrf.exe` | Main WRF simulation |
| `real.exe` | Generate initial/boundary conditions from real data |
| `ideal.exe` | Generate initial conditions for ideal cases |
| `ndown.exe` | One-way nesting |
| `tc.exe` | Tropical cyclone bogusing |

### WPS executables

| Binary | Status |
|--------|--------|
| `geogrid.exe` | Built |
| `metgrid.exe` | Built |
| `ungrib.exe` | Not built (requires JasPer 2.x for `jpc_decode` API) |

---

## 2  Typical Workflow

### Ideal case (no external data required)

```bash
docker run --rm -v $(pwd)/run:/run sci-wrf bash -c "
  cd /run && ln -sf /opt/WRF/run/* . &&
  cp /opt/WRF/test/em_quarter_ss/namelist.input . &&
  ln -sf /opt/WRF/main/ideal.exe . &&
  ./ideal.exe &&
  mpirun -np 2 --oversubscribe --allow-run-as-root wrf.exe
"
```

### Available ideal cases

| Case | Physics |
|------|---------|
| `test/em_quarter_ss` | Quarter-circle supercell storm |
| `test/em_b_wave` | Baroclinic wave |
| `test/em_squall2d_x` | 2-D squall line |

### Real-data case

```bash
# 1. WPS: prepare geographic and meteorological grids
docker run --rm -v $(pwd)/data:/data -v $(pwd)/run:/run sci-wrf bash -c "
  cd /run && ln -sf /opt/WPS/* . &&
  ./geogrid.exe &&
  ./metgrid.exe
"

# 2. real.exe: generate initial and boundary conditions
docker run --rm -v $(pwd)/run:/run sci-wrf bash -c "
  cd /run && ln -sf /opt/WRF/run/* . &&
  cp /your/namelist.input . &&
  mpirun -np 4 --oversubscribe --allow-run-as-root real.exe
"

# 3. wrf.exe: run the forecast
docker run --rm -v $(pwd)/run:/run sci-wrf bash -c "
  cd /run &&
  mpirun -np 4 --oversubscribe --allow-run-as-root wrf.exe
"
```

---

## 3  Multi-Node Run

### Start workers

```bash
# worker1.cluster.local
docker run -d --rm \
  --hostname worker1 --network host \
  -v $(pwd)/run:/run \
  --name wrf-worker1 sci-wrf /usr/sbin/sshd -D

# worker2.cluster.local
docker run -d --rm \
  --hostname worker2 --network host \
  -v $(pwd)/run:/run \
  --name wrf-worker2 sci-wrf /usr/sbin/sshd -D
```

### Run from head node

```bash
docker run --rm \
  --network host \
  -v $(pwd)/run:/run \
  sci-wrf \
  mpirun -np 6 --allow-run-as-root \
    --host $(hostname):2,worker1.cluster.local:2,worker2.cluster.local:2 \
    wrf.exe
```

WRF decomposes the domain across MPI ranks automatically.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

The `validate` service runs the quarter-circle supercell ideal case with 2 MPI
ranks. Expected: WRF startup banner, timestep output, and `wrfout_d01_*` files.

### Validate multi-node

```bash
docker compose up --abort-on-container-exit --exit-code-from head head
```

### Cleanup

```bash
docker compose down -v
```

---

## 5  ADIOS2 I/O

WRF v4.5+ supports ADIOS2 as an alternative I/O framework alongside NetCDF.
To use ADIOS2 output, set `io_form_history` and related `io_form_*` options in
`namelist.input` to the ADIOS2 I/O form number (consult the WRF Users' Guide
for the exact value in your version).

ADIOS2 is built with:
- MPI support (parallel I/O)
- HDF5 engine (can write ADIOS2 data as HDF5)
- Fortran bindings (used by WRF's `io_adios2` module)

---

## 6  Running WRF with Jarvis-CD

A [Jarvis-CD](https://github.com/grc-iit/jarvis-cd) package for WRF lives at
[`wrf/`](wrf/). It stages an `adios2.xml` (BP5 or Hermes engine) into the
WRF run directory and launches `wrf.exe` under MPI across the hosts in
the current Jarvis pipeline's hostfile.

```
wrf/
├── pkg.py                # Jarvis Application definition (class Wrf)
├── config/
│   ├── adios2.xml        # Template used when engine=bp5
│   ├── hermes.xml        # Template used when engine=hermes
│   └── namelist.input    # Reference namelist (io_form_* = 14 for ADIOS2)
└── README.md
```

Package options (exposed via `jarvis pipeline append wrf <key>=<val>`):

| Option | Default | Description |
|--------|---------|-------------|
| `nprocs` | `1` | Total MPI ranks passed to `mpirun -np`. |
| `ppn` | `None` | Ranks per node; Jarvis uses this with its hostfile. |
| `wrf_location` | `None` | Working dir containing `wrf.exe` + namelist; pkg `cwd`s here and writes `adios2.xml` here. |
| `engine` | `bp5` | `bp5` (native ADIOS2) or `hermes` (coeus-adapter plugin). |
| `Execution_order` | `None` | Hermes `execution_order` parameter (ignored for bp5). |
| `db_path` | `benchmark_metadata.db` | SQLite metadata DB (Hermes); `clean` removes it. |

### 6.1  Run single-node in the deployment container

Drive a 2-rank ideal-case run with Jarvis inside one `sci-wrf-deploy`
container:

```bash
docker run --rm -it \
  --name wrf-jarvis \
  -v "$(pwd)/wrf/..":/jarvis-pkgs/WRF \
  -v "$(pwd)/run":/run \
  sci-wrf-deploy bash

# --- inside the container ----------------------------------------------
pip install --break-system-packages \
    git+https://github.com/grc-iit/jarvis-cd.git \
    git+https://github.com/grc-iit/jarvis-util.git

jarvis bootstrap from local        # single-host config
jarvis repo add /jarvis-pkgs/WRF

# Prepare the WRF working directory.
mkdir -p /run/em_quarter_ss && cd /run/em_quarter_ss
ln -sf /opt/WRF/run/* .
ln -sf /opt/WRF/main/ideal.exe .
ln -sf /opt/WRF/main/wrf.exe   .
cp /opt/WRF/test/em_quarter_ss/namelist.input .
./ideal.exe                        # builds wrfinput_d01 / wrfbdy_d01

# Build + run the Jarvis pipeline.
jarvis pipeline create wrf_single
jarvis pipeline env build
jarvis pipeline append wrf \
    wrf_location=/run/em_quarter_ss \
    nprocs=2 ppn=2 engine=bp5
jarvis pipeline run

ls /run/em_quarter_ss/wrfout_d01_*
```

For the Hermes path (requires a deploy image extended with `hermes` +
`coeus-adapter`):

```bash
jarvis pipeline append hermes_run --sleep=10 provider=sockets
jarvis pipeline append wrf \
    wrf_location=/run/em_quarter_ss \
    nprocs=2 ppn=2 engine=hermes \
    Execution_order=0 \
    db_path=/run/em_quarter_ss/benchmark_metadata.db
jarvis pipeline run
```

### 6.2  Distribute the deploy container across nodes

The deploy image doubles as a worker by running `sshd`. A Jarvis head
container drives `mpirun` over SSH to the workers using a hostfile that
the `Wrf` pkg forwards to `MpiExecInfo`.

```bash
# --- on each physical worker node --------------------------------------
docker run -d --rm \
    --hostname worker1 --network host \
    -v $(pwd)/run:/run \
    --name wrf-worker1 sci-wrf-deploy /usr/sbin/sshd -D

docker run -d --rm \
    --hostname worker2 --network host \
    -v $(pwd)/run:/run \
    --name wrf-worker2 sci-wrf-deploy /usr/sbin/sshd -D
```

`/run/` must be a **shared** path visible on every node (NFS, Lustre,
cloud bucket fuse mount, etc.) — WRF ranks on the workers read the same
namelist, lookup tables, and input files the head prepared.

```bash
# --- on the head node --------------------------------------------------
docker run --rm -it \
    --hostname head --network host \
    -v $(pwd)/run:/run \
    -v $(pwd)/wrf/..:/jarvis-pkgs/WRF \
    --name wrf-head sci-wrf-deploy bash

# --- inside head -------------------------------------------------------
pip install --break-system-packages \
    git+https://github.com/grc-iit/jarvis-cd.git \
    git+https://github.com/grc-iit/jarvis-util.git

cat > /etc/hostfile <<EOF
head
worker1
worker2
EOF
jarvis bootstrap from local
jarvis hostfile set /etc/hostfile     # the pkg passes this to MpiExecInfo
jarvis repo add /jarvis-pkgs/WRF

# Stage the run directory (must be on the shared mount).
mkdir -p /run/em_quarter_ss && cd /run/em_quarter_ss
ln -sf /opt/WRF/run/* .
ln -sf /opt/WRF/main/ideal.exe .
ln -sf /opt/WRF/main/wrf.exe   .
cp /opt/WRF/test/em_quarter_ss/namelist.input .
./ideal.exe

# Run the Jarvis pipeline across 3 nodes, 2 ranks each.
jarvis pipeline create wrf_multi
jarvis pipeline env build
jarvis pipeline append wrf \
    wrf_location=/run/em_quarter_ss \
    nprocs=6 ppn=2 engine=bp5
jarvis pipeline run
```

Jarvis farms the ranks out per the hostfile; WRF handles domain
decomposition across the 6 MPI ranks.

### 6.3  Simulated Docker cluster validation

To validate the multi-node flow above on a single physical host, append
the following `jarvis-validate` service to `docker-compose.yml`. It
reuses the existing `worker1`/`worker2` services, the shared `output`
volume, and the `mpi-net` bridge.

```yaml
  jarvis-validate:
    image: sci-wrf-deploy:latest
    hostname: jarvis-head
    depends_on:
      worker1:
        condition: service_healthy
      worker2:
        condition: service_healthy
    volumes:
      - output:/output
      - ./wrf:/jarvis-pkgs/WRF/wrf:ro        # mount the pkg folder
    networks:
      - mpi-net
    command:
      - bash
      - -c
      - |
        set -e
        /usr/sbin/sshd

        pip install --break-system-packages --quiet \
            git+https://github.com/grc-iit/jarvis-cd.git \
            git+https://github.com/grc-iit/jarvis-util.git

        cat > /etc/hostfile <<EOF
        jarvis-head
        worker1
        worker2
        EOF
        jarvis bootstrap from local
        jarvis hostfile set /etc/hostfile
        jarvis repo add /jarvis-pkgs/WRF

        mkdir -p /output/em_quarter_ss && cd /output/em_quarter_ss
        ln -sf /opt/WRF/run/* .
        ln -sf /opt/WRF/main/ideal.exe .
        ln -sf /opt/WRF/main/wrf.exe   .
        cp /opt/WRF/test/em_quarter_ss/namelist.input .
        ./ideal.exe

        jarvis pipeline create wrf_ci
        jarvis pipeline env build
        jarvis pipeline append wrf \
            wrf_location=/output/em_quarter_ss \
            nprocs=3 ppn=1 engine=bp5
        jarvis pipeline run

        ls /output/em_quarter_ss/wrfout_d01_* \
          && echo '=== JARVIS CLUSTER TEST PASSED ==='
```

Run it:

```bash
docker compose build
docker compose up --abort-on-container-exit \
                 --exit-code-from jarvis-validate \
                 jarvis-validate
```

A passing run ends with `=== JARVIS CLUSTER TEST PASSED ===` and leaves
`wrfout_d01_*` files in `/output/em_quarter_ss/` on the shared volume.
Tear down with `docker compose down -v`.

---

## 7  Build Notes

- **HDF5 rebuild**: The base image's HDF5 is rebuilt in this Dockerfile to add
  zlib, szip (libaec), and Fortran support — all required by WRF/NetCDF.
- **HDF5 2.0.0 compatibility**: NetCDF-C and ADIOS2 are built with
  `-DH5_USE_114_API` for backward compatibility with the 2.0.0 API changes.
- **WRF configure option 34** = GNU (gfortran/gcc) dmpar on x86\_64 Linux.
  If building on a different platform, run `./configure` interactively.
- **WPS configure option 3** = GNU dmpar with GRIB2 support.
- **ungrib.exe**: Not built because JasPer 4.x removed the `jpc_decode` API
  that WPS expects. To fix, downgrade JasPer to 2.0.x in the Dockerfile.
- WRF runtime lookup tables (LANDUSE.TBL, RRTM data, etc.) are in `/opt/WRF/run/`.
  Always symlink them into your working directory before running `wrf.exe`.
