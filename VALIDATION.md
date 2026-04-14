# Validation Record

Status of each locally-authored workflow subdirectory in this repo. This
file records **what has been tested and what has not**, so a reviewer does
not need to re-derive the testing gap from scratch.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa`)

## Environment constraints on the validation host

| Capability | Status |
|---|---|
| `docker` binary | ✅ installed (v28.2.2) |
| Docker daemon access | ❌ user not in `docker` group |
| `sudo docker` | ❌ no passwordless sudo |
| `podman` (rootless) | ✅ v3.4.4 available |
| `podman-compose` | ❌ not installed |
| NVIDIA GPU | ❌ not available on this node |

Because the daemon is not reachable from this account, **no end-to-end image
build or container run has been executed here**. Everything below is
static validation only.

## Workflows added

| Directory | Upstream | Stack | Parallelism strategy |
|---|---|---|---|
| `montage/` | https://github.com/Caltech-IPAC/Montage | C toolkit, CPU-only | `mProjExec` fanned out over SSH |
| `biobb_wf_md_setup/` | https://github.com/bioexcel/biobb_wf_md_setup | Python + GROMACS (conda-forge), CPU-only | PDB inputs sharded round-robin across workers over SSH |

Both reuse `../base/Dockerfile` (`sci-hpc-base`). The CUDA layer in the base
is unused by these two apps but kept for consistency with the rest of the
repo.

## Validation performed

| Check | montage | biobb_wf_md_setup |
|---|---|---|
| `bash -n` on every shell driver (`run_mosaic.sh`, `run_batch.sh`) | ✅ | ✅ |
| `python3 -m py_compile` on Python driver (`run_md_setup.py`) | n/a | ✅ |
| `yaml.safe_load` on `docker-compose.yml` | ✅ | ✅ |
| Service set matches reference `vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted for CPU-only apps; all other fields present) | ✅ | ✅ |
| `podman build` parses `Dockerfile` without instruction errors (stops at missing base image, which is expected) | ✅ — 8 steps | ✅ — 8 steps |
| `podman build` parses `Dockerfile.deploy` without instruction errors | ✅ | ✅ |
| Image-name consistency across `Dockerfile` / `Dockerfile.deploy` / `docker-compose.yml` | ✅ | ✅ |
| README documents every file in the directory | ✅ | ✅ |

## Issues found and fixed during static validation

1. **Dockerfile heredoc was BuildKit-only.** Initial drafts embedded the
   driver scripts via `RUN cat > /opt/<script> <<'EOF' ... EOF`. `podman
   build` parsed that as 41 steps (montage) / 19 steps (biobb) because the
   classic Dockerfile parser treats each heredoc body line as a separate
   instruction — BuildKit heredocs are a Docker 23+ extension, not
   portable. Fix: promoted the embedded scripts to separate files
   (`run_mosaic.sh`, `run_md_setup.py`, `run_batch.sh`) and switched to
   `COPY`. Now parses to 8 steps per Dockerfile, matching the `vpic/`
   reference.

2. **Montage image-table header-line hardcoding.** The initial driver used
   `tail -n +4` / `head -n 3` to split Montage's `images.tbl` — fragile
   because Montage tables have variable-length headers (`\keyword=value`
   lines plus 1-4 `|`-prefixed column/type/unit/null rows). Fix: replaced
   with `awk '/^[\\|]/'` header detection.

3. **biobb driver unguarded exceptions.** Initial driver called
   `os.path.getsize(fixed)` after `fix_side_chain`; if that raised, the
   whole script would crash unhandled and later steps never ran. Fix:
   wrapped each of steps 2-5 in its own `try/except`, added an `ok(path)`
   helper, and gated each step on the previous step's `PASS` status.

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB)
  - compiling parallel HDF5 2.0.0 from source (in the base image)
  - internet access to clone Montage, fetch 2MASS FITS via `mArchiveExec`,
    pull `Miniforge3-Linux-x86_64.sh`, download `gromacs=2026` from
    conda-forge, `pip install biobb_*`, and fetch `1AKI.pdb` from RCSB
- `docker compose run --rm validate` actually produces `mosaic.fits`
  (montage) / `1AKI_solvate.gro` (biobb)
- `docker compose up head` (with worker1/worker2 healthy) actually
  completes the SSH fan-out over the `mpi-net` overlay network and produces
  the same output artefacts

## How the bare-metal workflow was validated (pre-containerisation)

The underlying pipelines were validated on bare-metal Ares on 2026-03-27 as
part of the upstream `hpc_workflows` benchmarking suite. The Dockerfiles in
this repo encode the same recipes that succeeded on bare metal. See the
upstream project's `summaries/Montage_PHASE6_SUMMARY.txt` and
`summaries/biobb_wf_md_setup_PHASE6_SUMMARY.txt`.

| Workflow | Scale | Bare-metal result |
|---|---|---|
| Montage | small (4 FITS, M17) | ✅ SUCCESS, `mosaic.fits` 1.2 MB, ~3 s |
| Montage | medium (16 FITS) | ✅ SUCCESS, `mosaic.fits` 19 MB, ~12 s |
| biobb_wf_md_setup | small (1AKI) | ✅ SUCCESS, all 5 steps PASS, ~3 s |
| biobb_wf_md_setup | medium (8 PDBs) | ✅ 3/8 fully solvated (5 failed at `pdb2gmx` due to non-standard residues — expected behaviour, not a bug) |
