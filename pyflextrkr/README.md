# PyFLEXTRKR — Python FLEXible object TRacKeR

[PyFLEXTRKR](https://github.com/FlexTRKR/PyFLEXTRKR) is a Python framework
for tracking atmospheric features — mesoscale convective systems,
convective cells, cyclones, etc. — across time-sequenced gridded fields.
It is developed primarily at PNNL and backs several observational/model
MCS tracking workflows.

The container is **CPU-only**. PyFLEXTRKR has three parallel modes:

| `run_parallel` | Mode | Status in this image |
|---|---|---|
| `0` | serial | ✅ used by `run_demo.sh` for single-node self-test |
| `1` | Dask `LocalCluster` | ❌ known HDF5 concurrent-access bug — not used |
| `2` | Dask-MPI (distributed) | ✅ used by `run_demo_multinode.sh` across SSH hosts |

The multi-node mode runs **one real distributed Dask cluster** spanning
every host in the MPI world, not three independent copies of the demo.
Rank 0 hosts the scheduler, rank 1 runs the pipeline driver, and the
remaining ranks are workers. The `h5netcdf` engine is substituted for
`netcdf4` at runtime to avoid the same HDF5 global-lock deadlock that
breaks mode 1.

The self-test exercises `demo_mcs_tbpf_idealized` — the smallest upstream
demo case — which downloads a ~1-2 MB idealized Tb+precipitation dataset
and runs the full 9-step MCS tracking pipeline.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access during the builder build (PyFLEXTRKR clone + pip deps)
  **and at container run time** (the demo runner downloads sample data on
  first use from `portal.nersc.gov`).

---

## 1  Build

```bash
docker build -t sci-hpc-base            ../base
docker build -t sci-pyflextrkr          .
docker build -t sci-pyflextrkr-deploy   -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

```bash
docker run --rm -v $(pwd)/output:/output sci-pyflextrkr-deploy \
  /opt/run_demo.sh demo_mcs_tbpf_idealized /output/data
```

The wrapper invokes `python tests/run_demo_tests.py --demos <demo>
--data-root <data_root> -n 1`, so the entire upstream demo harness runs
(download → config templating → tracking → output validation).

### Other demos

The upstream list (add `--with-plots` for ffmpeg animations):

```bash
docker run --rm sci-pyflextrkr-deploy \
  python /opt/PyFLEXTRKR/tests/run_demo_tests.py --list
```

Run a different case:

```bash
docker run --rm -v $(pwd)/output:/output sci-pyflextrkr-deploy \
  /opt/run_demo.sh demo_cell_nexrad /output/data
```

---

## 3  Multi-Node Run

Real distributed Dask via Dask-MPI across SSH-reachable hosts. `mpirun`
is launched once from the head container and spans every node.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network mpi-net \
  --name pyflextrkr-worker1 sci-pyflextrkr-deploy /usr/sbin/sshd -D
docker run -d --rm --hostname worker2 --network mpi-net \
  --name pyflextrkr-worker2 sci-pyflextrkr-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network mpi-net \
  -v $(pwd)/output:/output \
  sci-pyflextrkr-deploy bash -c '
    /usr/sbin/sshd &&
    /opt/run_demo_multinode.sh /output/cluster head,worker1,worker2 6'
```

`run_demo_multinode.sh`:

1. runs the upstream demo harness once serially to download the
   ~1-2 MB idealized dataset and template its config,
2. flips `run_parallel: 2` in that config,
3. wipes the seed's `stats/`/`tracking/`/`mcstracking/`,
4. launches `mpirun -np N -host head,worker1,worker2 python
   /opt/run_mcs_tbpf_mpi.py config.yml` — one real Dask-MPI cluster,
5. asserts the MPI pass re-wrote `stats/`.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

Expected tail: `=== SINGLE-NODE TEST PASSED ===`.

### Validate multi-node

```bash
docker compose up --abort-on-container-exit --exit-code-from head head
```

The head container starts the demo on itself and on both workers in
parallel over SSH, then asserts that each node produced its own `stats/`
directory. Expected tail: `=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-pyflextrkr`): Python 3.10 venv + PyFLEXTRKR editable install + `dask-mpi`/`mpi4py`/`h5netcdf`/`healpy`. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-pyflextrkr-deploy`): Ubuntu 24.04 + baked venv + upstream source tree + `openmpi-bin`/`libopenmpi3t64` + SSH. |
| `docker-compose.yml` | `validate` (single-node serial demo) and `head`/`worker1`/`worker2` (one Dask-MPI cluster spanning three containers). |
| `run_demo.sh` | Wrapper around `tests/run_demo_tests.py` that forces `-n 1` (serial) and asserts a non-empty `stats/` directory is produced. Installed at `/opt/run_demo.sh`. |
| `run_demo_multinode.sh` | Seeds data via the harness, flips `run_parallel: 2`, wipes outputs, launches one `mpirun` across supplied hosts. Installed at `/opt/run_demo_multinode.sh`. |
| `run_mcs_tbpf_mpi.py` | Dask-MPI variant of upstream `runscripts/run_mcs_tbpf.py`. Calls `dask_mpi.initialize()`, monkey-patches `xr.open_dataset` to use `h5netcdf` (with NetCDF3 fallback). Installed at `/opt/run_mcs_tbpf_mpi.py`. |
| `README.md` | This file. |
| `VALIDATION.md` | Record of what has and has not been tested. |

---

## References

- Feng, Z., et al. (2023). "PyFLEXTRKR: a flexible feature tracking Python
  software for convective cloud analysis." *Geoscientific Model
  Development* 16, 2753-2776.
- https://github.com/FlexTRKR/PyFLEXTRKR
