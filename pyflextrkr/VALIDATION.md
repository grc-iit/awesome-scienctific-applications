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

Because the daemon is not reachable from this account, **no end-to-end
image build or container run has been executed here**. Everything below
is static validation only.

## Validation performed

| Check | Result |
|---|---|
| `bash -n run_demo.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 9 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-pyflextrkr:latest`, expected) |
| Image-name consistency (`sci-pyflextrkr` / `sci-pyflextrkr-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Design notes

- The self-test delegates to upstream `tests/run_demo_tests.py`, which is
  authored and maintained by the PyFLEXTRKR team. This keeps the
  container's demo logic aligned with upstream rather than forking it.
- The wrapper forces `-n 1` (serial). The bare-metal benchmark this
  container mirrors had to fall back from Dask parallel to serial because
  of an HDF5 concurrent-access bug in the Dask local-cluster mode — the
  upstream demo shows the same behaviour. If and when upstream fixes this,
  bump `-n` in `run_demo.sh`.
- Multi-node parallelism is expressed as "same demo, three nodes, three
  output dirs" rather than Dask-across-nodes. This demonstrates the SSH
  fan-out layer without fighting the HDF5 bug.

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - compiling parallel HDF5 2.0.0 from source (in the base image)
  - cloning `FlexTRKR/PyFLEXTRKR` and running `pip install -e .` with
    scientific-Python wheels (xarray, dask, netCDF4, scipy, scikit-image).
- `docker compose run --rm validate` actually:
  - downloads `idealized_tbpcp.tar.gz` from `portal.nersc.gov` at runtime
  - completes the full 9-step MCS tracking pipeline on that data
  - produces a non-empty `stats/` directory
- `docker compose up head` completes the three-way SSH fan-out across
  `head`/`worker1`/`worker2` on the `mpi-net` overlay.

## Bare-metal validation (pre-containerisation)

The PyFLEXTRKR pipeline was validated on bare-metal Ares on 2026-03-27 as
part of the upstream `hpc_workflows` benchmarking suite. See that repo's
`summaries/PyFLEXTRKR_PHASE6_SUMMARY.txt`.

| Scale | Result |
|---|---|
| small (NEXRAD, 35 netCDF files, ~2.5 min) | ✅ SUCCESS after 1 self-repair (Dask parallel → serial) |
| medium (GPM IMERG, 98 netCDF files, ~7 min) | ✅ SUCCESS first attempt (serial) |
