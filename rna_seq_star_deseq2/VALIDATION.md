# Validation Record — rna_seq_star_deseq2

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/rna_seq_star_deseq2`)

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
is static validation only, with the exception of the bare-metal Ares
re-run described below (which exercised the same pipeline logic
outside the container).

## Validation performed

| Check | Result |
|---|---|
| `bash -n run_rnaseq.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 11 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-rna-seq-star-deseq2:latest`, expected) |
| Image-name consistency (`sci-rna-seq-star-deseq2` / `…-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Design notes

- Workflow is pinned to **v2.2.0**, Snakemake to **9.18.2** — the exact
  combination validated by the bare-metal Ares re-run (see below).
- Per-rule tool envs are **not** materialised at build time. Snakemake
  creates them on first `--use-conda` run under
  `/opt/conda/envs/rnaseq-tools`. This trades a smaller image for a
  slower first-run experience (~10-15 min of solves).
- `PYTHONNOUSERSITE=1` is set in both images to keep the baked env
  hermetic, matching the convention used by `../vpipe/`.
- The bundled benchmark (`bench/ngs-test-data/` + `bench/*.tsv`) is
  copied from the upstream `config_basic/` preset and lives at
  `/opt/rnaseq-bench/` inside the images. The driver only stages it
  into a workdir if the workdir is empty, so user-supplied data is not
  overwritten.

## Bare-metal Ares re-run (2026-04-14)

The bare-metal pipeline was re-submitted under SLURM job **7963** as
part of the upload-asa fit-check. Evidence file:
`runs/rna-seq-star-deseq2/small/logs/stdout.log`.

| Metric | Result |
|---|---|
| Exit code | 0 |
| Snakemake DAG | 53 / 53 steps done (100 %) |
| Elapsed | 1311 s (~22 min) |
| Output size | 25 MB under `results/` (counts / deseq2 / diffexp / pca / qc / star / trimmed) |
| stdout error-pattern scan (`^(error\|fatal\|traceback\|critical)`) | 0 hits |

This is a clean end-to-end success on the real pipeline logic, which
gives the container packaging a solid recipe to mirror.

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - downloading the Miniforge installer, creating a conda env with
    Snakemake 9.18.2
  - cloning the workflow at tag v2.2.0
- `docker compose run --rm validate`:
  - solves all per-rule tool conda envs on first run
  - completes the full Snakemake DAG on the bundled S. cerevisiae
    benchmark
  - produces a `*.diffexp.symbol.tsv` and STAR `Aligned*.bam` under
    `/output/run/results/`
- `docker compose up head`: three-way SSH fan-out across
  `head`/`worker1`/`worker2` on the `mpi-net` overlay; each project
  directory must produce its own diffexp table.
