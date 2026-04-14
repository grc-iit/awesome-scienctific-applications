# Validation Record — vpipe

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/vpipe`)

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
| `bash -n run_vpipe.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 10 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-vpipe:latest`, expected) |
| Image-name consistency (`sci-vpipe` / `sci-vpipe-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Design notes

- V-pipe is pinned to tag **v3.0.0**, Snakemake to **7.32.4**. V-pipe
  calls `load_configfile`, which was removed in Snakemake 8; the
  bare-metal benchmark hit this. Do not bump Snakemake here until V-pipe
  upstream drops that dependency.
- `PYTHONNOUSERSITE=1` is set in both images; without it the bare-metal
  benchmark silently imported the user's `~/.local` pandas and failed.
- The per-rule conda envs V-pipe needs for its tools (BWA, samtools,
  etc.) are **not** materialised at build time. Snakemake creates them
  on first `--use-conda` run under `/opt/conda/envs/vpipe-tools`. This
  trades a faster image build for a slower first-run experience
  (~5-10 min additional solve time).

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - downloading the Miniforge installer, creating a conda env with
    Snakemake 7.32.4
  - cloning V-pipe v3.0.0
- `docker compose run --rm validate`:
  - solves all per-rule conda envs on first run
  - completes the SARS-CoV-2 Snakemake DAG
  - produces files under `/output/run/results/`
- `docker compose up head`: three-way SSH fan-out of `sars-cov-2` /
  `hiv` / `sars-cov-2` runs across head + worker1 + worker2.

## Bare-metal validation (pre-containerisation)

The V-pipe SARS-CoV-2 workflow was validated on bare-metal Ares on
2026-03-27 as part of the upstream `hpc_workflows` benchmarking suite.
See that repo's `summaries/V-pipe_PHASE6_SUMMARY.txt`.

| Scale | Result |
|---|---|
| small (SARS-CoV-2, 2 samples, QA + SNV calling) | ✅ SUCCESS — all 35 Snakemake steps completed, ~1457 s |
| medium | skipped — small covered the regression surface, medium not attempted |
