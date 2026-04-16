# Validation Record — pyflextrkr

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/pyflextrkr`)

## Environment constraints on the validation host

| Capability | Status |
|---|---|
| `docker` binary | ✅ installed (v28.2.2) |
| Docker daemon access | ❌ user not in `docker` group |
| `sudo docker` | ❌ no passwordless sudo |
| `podman` (rootless) | ✅ v3.4.4 available |
| `podman-compose` | ❌ not installed |
| NVIDIA GPU | ❌ not available on this node |
| Slurm (bare-metal multi-node) | ✅ `debug` partition, ≥5 idle nodes |
| mpich 4.1.1 | ✅ `/mnt/repo/software/modules-install/mpich/4.1.1` |

Because the Docker daemon is not reachable from this account, **no
end-to-end image build or container run has been executed here**.
However, the Dask-MPI recipe the image bakes in has been fully validated
on bare-metal Slurm (see "Bare-metal multi-node validation" below).

## Static validation performed

| Check | Result |
|---|---|
| `bash -n run_demo.sh` / `bash -n run_demo_multinode.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| `podman build -f Dockerfile` parse | ✅ 12 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ stage 1 + stage 2/14 steps (stops at missing `sci-pyflextrkr:latest`, expected) |
| Image-name consistency (`sci-pyflextrkr` / `sci-pyflextrkr-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |
| `python -c 'import ast; ast.parse(open("run_mcs_tbpf_mpi.py").read())'` | ✅ |

## Bare-metal multi-node validation (Slurm, 2026-04-14)

The **exact launcher logic** that the container bakes into
`run_demo_multinode.sh` / `run_mcs_tbpf_mpi.py` was executed outside
Docker under Slurm on Ares. This gives end-to-end evidence that the
Dask-MPI recipe works — the container just wraps it.

Job: `7978` — partition `debug`, 2 nodes (`ares-comp-[03-04]`),
`--ntasks-per-node=2` → 4 MPI ranks (1 scheduler + 1 client + 2
workers). Launched as:

```bash
mpirun -n $SLURM_NTASKS -bind-to none -map-by slot \
    -genv HDF5_USE_FILE_LOCKING FALSE \
    python run_mcs_tbpf_mpi.py config_multinode.yml
```

Input data: `medium` scale (GPM IMERG, 48 hourly Tb+precipitation
NetCDF files, 2019-01-25..27) — same fixture as the existing
bare-metal serial benchmark.

| Result | Value |
|---|---|
| Exit code | 0 |
| Wall time | 6 min 30 s |
| All 9 pipeline steps completed | ✅ idfeature, tracksingle, gettracks, trackstats, identifymcs, matchtbpf, robustmcspf, mapfeature, movement_speed |
| `stats/` files produced | 8 (identical set to serial reference) |
| `tracking/` files | 95 (identical count) |
| `mcstracking/` pixel files | 48 (identical count) |
| Byte-identical vs serial | `grid_area_from_latlon.nc`, `tracknumbers_*.nc`, `trackstats_*.nc`, `trackstats_sparse_*.nc` |
| Scientific content parity | `mcs_tracks_final`: 25 tracks × 400 times — identical to serial |
| Fatal errors in log | **none** (only cosmetic `distributed.comm.core.CommClosedError` during post-success MPI teardown) |

Artefacts: `/mnt/common/mtang11/hpc_workflows/runs/PyFLEXTRKR/multinode_test/`
(`run_slurm.sh`, `run_mcs_tbpf_mpi.py`, `config_multinode.yml`,
`pyflex_mn_7978.out`).

### Required runtime fixes discovered during validation

Without these, the pipeline segfaults or deadlocks during `tracksingle`
/ `matchtbpf`. All are baked into the image:

1. `HDF5_USE_FILE_LOCKING=FALSE` — the shared FS (OrangeFS) doesn't
   honour HDF5's advisory locks.
2. `xr.set_options(file_cache_maxsize=1)` — xarray's per-process
   netCDF4 file_manager LRU cache deadlocks across Dask pickling
   boundaries.
3. `xr.open_dataset` monkey-patched to prefer `engine='h5netcdf'`, with
   fallback to `engine='netcdf4'` for classic NetCDF3 inputs
   (e.g. `IMERG_landmask_saag.nc`).
4. The patch is applied on the client **and** broadcast to every worker
   via `client.run(_install_h5netcdf_patch)`.
5. Extra pip deps layered into the venv: `mpi4py`, `dask-mpi`,
   `h5netcdf`, `h5py`, `healpy` (the last is required by
   `pyflextrkr.remap_healpix_zarr`, which the upstream runscript
   unconditionally imports).

## Bare-metal serial validation (pre-containerisation, 2026-03-27)

| Scale | Result |
|---|---|
| small (NEXRAD, 35 netCDF files, ~2.5 min) | ✅ SUCCESS after 1 self-repair (Dask parallel → serial) |
| medium (GPM IMERG, 48 netCDF files, ~7 min serial) | ✅ SUCCESS |
| medium (GPM IMERG, 48 netCDF files, ~6.5 min Dask-MPI × 4 ranks) | ✅ SUCCESS (job 7978 above) |

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - compiling parallel HDF5 2.0.0 from source (in the base image)
  - cloning `FlexTRKR/PyFLEXTRKR` and running `pip install -e .`
  - pip-installing `mpi4py`/`dask-mpi`/`h5netcdf`/`h5py`/`healpy`
    (mpi4py will link against the base image's openmpi).
- `docker compose run --rm validate` actually:
  - downloads `idealized_tbpcp.tar.gz` from `portal.nersc.gov` at runtime
  - completes the full 9-step MCS tracking pipeline on that data
  - produces a non-empty `stats/` directory.
- `docker compose up head` completes the three-container Dask-MPI run.
  The logic is the same as the Slurm-validated run — only difference is
  `mpirun` uses SSH transport (openmpi + `--allow-run-as-root`) rather
  than mpich Hydra + Slurm PMI to reach the other hosts.
