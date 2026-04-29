# Validation Record — nf-core_differentialabundance

Last updated: 2026-04-29
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/nf-core_differentialabundance`)

## Environment constraints on the validation host

| Capability | Status |
|---|---|
| `docker` binary | ✅ installed (v28.2.2) |
| Docker daemon access | ❌ user not in `docker` group |
| `sudo docker` | ❌ no passwordless sudo |
| `podman` (rootless) | ✅ v3.4.4 available |
| `podman-compose` | ❌ not installed |
| NVIDIA GPU | ❌ not available on this node |

No end-to-end image build or container run executed here. Static validation only.

## Validation performed

| Check | Result |
|---|---|
| `bash -n run_differentialabundance.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpipe/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpipe (CPU-only, no `deploy.devices[nvidia]`) | ✅ |
| Image-name consistency (`sci-nf-differentialabundance` / `sci-nf-differentialabundance-deploy`) | ✅ |

## Bare-metal multi-node validation (2026-04-28)

nf-core/differentialabundance at 4-node Ares SLURM:

- 4 SLURM nodes allocated; Nextflow driver submitted child sbatch jobs via `executor='slurm'`, tasks landing across compute nodes (real multi-node deployment).
- **12 blk_trace JSONs captured** under DataLife profiling.
- ELAPSED_SECONDS=500, see `paper_widget/data/multinode_profile/nf-core_differentialabundance/datalife_2026-04-21_4node/`.

## What has **not** been validated (requires a docker-capable host)

- Actual image build (pulls `nvidia/cuda:12.6.0-devel-ubuntu24.04` + Miniforge).
- `docker compose run --rm validate` end-to-end with `-profile test,conda`.
- `docker compose up head` 3-way cluster fan-out.
