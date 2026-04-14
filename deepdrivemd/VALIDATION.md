# Validation Record — deepdrivemd

Status of what has and has not been tested for this workflow.

Last updated: 2026-04-14
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/deepdrivemd`)

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
| `bash -n run_ddmd.sh` | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| `yaml.safe_load(deepdrivemd.template.yaml)` (pre-sed; placeholders treated as strings) | ✅ |
| Service set vs `../vpic/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Per-service field set vs vpic (`deploy.devices[nvidia]` correctly omitted — placeholder-mode CPU-only) | ✅ |
| `podman build -f Dockerfile` Dockerfile parse | ✅ — 13 steps (stops at missing `sci-hpc-base`, expected) |
| `podman build -f Dockerfile.deploy` parse | ✅ (stops at missing `sci-deepdrivemd:latest`, expected) |
| Image-name consistency (`sci-deepdrivemd` / `sci-deepdrivemd-deploy`) across all three Docker files | ✅ |
| README documents every file in the directory | ✅ |

## Design notes

- **Placeholder executables.** All four DDMD stages
  (`molecular_dynamics_stage`, `aggregation_stage`, `machine_learning_stage`,
  `model_selection_stage`, `agent_stage`) have `executable: /bin/echo`.
  This matches the bare-metal smoke test, which deliberately exercised
  only the framework (config parsing, stage sequencing, iterative loop)
  rather than the real MD/ML stack. Real simulations require a GPU + an
  OpenMM driver; swapping placeholders for a real `md.py` is the last
  step before production use.
- **Dependency pins mirror the bare-metal recipe.** `pydantic==1.10.26`
  (DDMD's schema is v1-only); `PyYAML==6.0.3` (pin `<6.0.0` relaxed, API
  compatible); `h5py==3.16.0` (pin `==2.10.0` doesn't build on
  Python 3.10+); `openmm==8.5.0`; `radical.entk/pilot/utils==1.103.x`.
  Updating any of these is risky — run the smoke first.
- **`RADICAL_BASE` per-experiment.** The driver sets `RADICAL_BASE` to
  the experiment dir so RADICAL sandboxes don't collide between
  concurrent runs (needed for the multi-node target where three
  experiments run in parallel against the same shared `/output` volume).
- **Self-cfg patch applied at build time.** DDMD v0.0.2's
  `deepdrivemd/deepdrivemd.py` references bare `cfg` (not `self.cfg`)
  on lines 70 and 73; the patch in `deepdrivemd-selfcfg.patch` fixes
  this. Same patch the bare-metal run applied.

## What has **not** been validated (requires a working Docker host)

- Actual image build succeeds. Depends on:
  - pulling `nvidia/cuda:12.6.0-devel-ubuntu24.04` (~3-4 GB, inherited
    from `sci-hpc-base`)
  - pip-installing the RADICAL stack, OpenMM 8.5, MDAnalysis, MD-tools
    from GitHub, and cloning DeepDriveMD
  - fetching `1FME.pdb` from RCSB
- `docker compose run --rm validate`:
  - renders the template, sets `RADICAL_BASE`, runs
    `python -m deepdrivemd.deepdrivemd`
  - all four stages transition `DONE`
  - at least one `stage*` sub-directory is created
- `docker compose up head` completes the three-way SSH fan-out across
  `head`/`worker1`/`worker2` on the `mpi-net` overlay, including the
  larger `worker2` run (`max_iter=2`, `num_tasks=4`).

## Bare-metal validation (pre-containerisation)

The DDMD pipeline was validated on bare-metal Ares on 2026-03-27 as
part of the upstream `hpc_workflows` benchmarking suite. See that repo's
`summaries/DeepDriveMD-pipeline_PHASE6_SUMMARY.txt`.

| Scale | Result |
|---|---|
| small (1 iter, 1 MD task, `/bin/echo` placeholders) | ✅ SUCCESS — all 4 stages DONE, exit 0, ~37 s |
| medium (2 iter, 4 MD tasks, `/bin/echo` placeholders) | ✅ SUCCESS — both iterations completed, 4 stages DONE each, exit 0, ~37 s |

Real MD runs (OpenMM driver, GPU nodes) were not part of the
bare-metal benchmark scope.
