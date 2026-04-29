# Validation Record — nf-core_bacass

Last updated: 2026-04-29
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/nf-core_bacass`)

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
| `bash -n run_bacass.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpipe/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpipe (`deploy.devices[nvidia]` correctly omitted — CPU-only) | ✅ |
| Image-name consistency (`sci-nf-bacass` / `sci-nf-bacass-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Bare-metal multi-node validation (2026-04-28)

nf-core/bacass at 4-node Ares SLURM ran successfully:

- 4 SLURM nodes allocated; Nextflow driver on 1 head node submitted child sbatch jobs via `executor='slurm'`, with tasks landing on the other compute nodes (real multi-node deployment).
- 282 blk_trace JSONs captured under DataLife profiling. See `paper_widget/data/multinode_profile/nf-core_bacass/datalife_2026-04-21_4node/`.
- `EXIT_CODE=0`, ~2h elapsed, 127 MB outputs.
- Source benchmark dir: `hpc_workflows/runs/nf-core_bacass/small_4node/`.

## What has **not** been validated (requires a docker-capable host)

- Actual image build succeeds; pulls `nvidia/cuda:12.6.0-devel-ubuntu24.04` and Miniforge.
- `docker compose run --rm validate`: completes the full nf-core/bacass DAG with `-profile test,conda` and produces `outputs/`.
- `docker compose up head`: 3-way cluster fan-out with all 3 nodes producing `outputs/`.
