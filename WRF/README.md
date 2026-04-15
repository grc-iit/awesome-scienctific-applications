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

## 6  Build Notes

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
