# Validation Record — metagem

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/metagem`)

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
| `bash -n run_metagem.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 11 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-metagem:latest`, expected) |
| Image-name consistency (`sci-metagem` / `sci-metagem-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Design notes

- **Scope is deliberately narrowed to the `qfilter` target.** The full
  metaGEM pipeline pulls in megahit, concoct, maxbin, metabat, GTDBTk,
  COBRApy, SMETANA, memote, etc. — each with its own conda env. Packaging
  all of those would push the image well over 10 GB and the first-run
  materialisation would take hours. Users who want downstream stages
  pass extra rule names to `run_metagem.sh`; the Snakemake DAG is
  otherwise unchanged.
- **Patch is applied at build time.** Upstream metaGEM still calls
  `source activate` (the pre-4.4 conda API), which breaks with modern
  conda. `metagem-conda-activate.patch` rewrites those calls to use
  `conda shell.bash hook`. This matches the patch the bare-metal
  benchmark applied.
- **Config placeholders are rewritten by the driver**, not by the build.
  Upstream `config/config.yaml` has `/path/to/project/...` placeholders;
  `run_metagem.sh` sed's them to the requested workdir so the image is
  not tied to a specific host path.
- **Toy data is fetched on demand.** `run_metagem.sh` only invokes
  upstream's `downloadToy` rule if the workdir's `dataset/` is empty,
  which keeps the image small and gives users a clean override path
  (drop FASTQs in `dataset/<sample>/<sample>_R1.fastq.gz` before
  launching).

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - downloading the Miniforge installer, creating two conda envs
    (Snakemake 9 and fastp)
  - cloning metaGEM from upstream and applying the conda-activate patch
- `docker compose run --rm validate`:
  - calls `downloadToy` to fetch the toy dataset on first run
  - runs the metaGEM `qfilter` target to completion
  - produces `*_R1.fastq.gz` files under `/output/run/qfiltered`
- `docker compose up head` completes the three-way SSH fan-out across
  `head`/`worker1`/`worker2` on the `mpi-net` overlay.

## Bare-metal validation (pre-containerisation)

The metaGEM qfilter workflow was validated on bare-metal Ares on
2026-03-27 as part of the upstream `hpc_workflows` benchmarking suite.
See that repo's `summaries/metaGEM_PHASE6_SUMMARY.txt`.

| Scale | Result |
|---|---|
| small (3 paired-end samples, 1.8 GB input) | ✅ SUCCESS after 3 self-repairs (config paths, Snakefile `source activate → conda activate`, fastp env creation) — 4 qfilter steps, ~748 s, 1.6 GB output |
| medium | skipped — small covered the regression surface |
