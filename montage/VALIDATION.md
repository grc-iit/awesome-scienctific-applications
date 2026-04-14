# Validation Record — montage

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/montage`)

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
| `bash -n run_mosaic.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 8 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-montage:latest`, expected) |
| Image-name consistency (`sci-montage` / `sci-montage-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Issues found and fixed during static validation

1. **Dockerfile heredoc was BuildKit-only.** Initial draft embedded
   `run_mosaic.sh` via `RUN cat > /opt/run_mosaic.sh <<'EOF' ... EOF`.
   `podman build` parsed that as 41 instructions because the classic
   Dockerfile parser treats each heredoc body line as a separate
   instruction (BuildKit heredocs are a Docker 23+ extension, not
   portable). Fix: promoted the script to `run_mosaic.sh` alongside the
   Dockerfile and switched to `COPY`. Now parses to 8 steps, matching
   `vpic/`.

2. **Image-table header-line hardcoding.** The initial driver used
   `tail -n +4` / `head -n 3` to split Montage's `images.tbl` — fragile
   because Montage tables have variable-length headers (`\keyword=value`
   lines plus 1-4 `|`-prefixed column/type/unit/null rows). Fix: replaced
   with `awk '/^[\\|]/'` header detection that survives any header shape.

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - compiling parallel HDF5 2.0.0 from source (in the base image)
  - internet access to clone Montage and fetch 2MASS FITS via
    `mArchiveExec` at build time
- `docker compose run --rm validate` actually produces `mosaic.fits`
- `docker compose up head` completes the SSH fan-out of `mProjExec`
  across `head`/`worker1`/`worker2` on the `mpi-net` overlay and produces
  the same `mosaic.fits`

## Bare-metal validation (pre-containerisation)

The Montage 10-step pipeline encoded in `run_mosaic.sh` was validated on
bare-metal Ares on 2026-03-27 as part of the upstream `hpc_workflows`
benchmarking suite. See that repo's `summaries/Montage_PHASE6_SUMMARY.txt`.

| Scale | Result |
|---|---|
| small (4 FITS, M17) | ✅ SUCCESS, `mosaic.fits` 1.2 MB, ~3 s |
| medium (16 FITS) | ✅ SUCCESS, `mosaic.fits` 19 MB, ~12 s |
