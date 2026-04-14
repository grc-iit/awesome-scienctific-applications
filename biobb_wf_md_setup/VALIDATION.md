# Validation Record — biobb_wf_md_setup

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/biobb_wf_md_setup`)

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
| `bash -n run_batch.sh` | ✅ |
| `python3 -m py_compile run_md_setup.py` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 8 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-biobb-md-setup:latest`, expected) |
| Image-name consistency (`sci-biobb-md-setup` / `sci-biobb-md-setup-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Issues found and fixed during static validation

1. **Dockerfile heredoc was BuildKit-only.** Initial draft embedded
   `run_md_setup.py` and `run_batch.sh` via `RUN cat > ... <<'EOF' ... EOF`.
   `podman build` parsed that as 19 instructions because the classic
   Dockerfile parser treats each heredoc body line as a separate
   instruction (BuildKit heredocs are a Docker 23+ extension, not
   portable). Fix: promoted both scripts to files alongside the
   Dockerfile and switched to `COPY`. Now parses to 8 steps, matching
   `vpic/`.

2. **Unguarded exceptions in the Python driver.** Initial driver called
   `os.path.getsize(fixed)` immediately after `fix_side_chain`; if
   `fix_side_chain` raised, the whole script crashed unhandled and later
   steps never ran. Fix: wrapped each of steps 2-5 in its own
   `try/except`, added an `ok(path)` helper, and gated every step on the
   previous step's `PASS` status so a failure short-circuits cleanly
   instead of cascading.

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - compiling parallel HDF5 2.0.0 from source (in the base image)
  - downloading the Miniforge installer, creating a conda env with
    `gromacs=2026` from conda-forge, `pip install biobb_*`, and fetching
    `1AKI.pdb` from RCSB — all at build time
- `docker compose run --rm validate` actually produces
  `1AKI_solvate.gro`
- `docker compose up head` completes the SSH round-robin of PDBs across
  `head`/`worker1`/`worker2` on the `mpi-net` overlay and writes one
  `_solvate.gro` per input PDB

## Bare-metal validation (pre-containerisation)

The 5-step pipeline encoded in `run_md_setup.py` was validated on
bare-metal Ares on 2026-03-27 as part of the upstream `hpc_workflows`
benchmarking suite. See that repo's
`summaries/biobb_wf_md_setup_PHASE6_SUMMARY.txt`.

| Scale | Result |
|---|---|
| small (1AKI) | ✅ SUCCESS, all 5 steps PASS, ~3 s |
| medium (8 PDBs) | ✅ 3/8 fully solvated; 5 failed at `pdb2gmx` due to non-standard residues with the default AMBER99SB-ILDN force field (expected behaviour, not a bug) |
