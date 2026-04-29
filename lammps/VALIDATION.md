# Validation Record — lammps

Last updated: 2026-04-29
Host: Ares login node (`/mnt/common/mtang11/hpc_workflows/upload-asa/lammps`)

## Environment constraints on the validation host

| Capability | Status |
|---|---|
| `docker` binary | ✅ installed (v28.2.2) |
| Docker daemon access | ❌ user not in `docker` group |
| `sudo docker` | ❌ no passwordless sudo |
| `podman` (rootless) | ✅ v3.4.4 available |
| `podman-compose` | ❌ not installed |
| NVIDIA GPU | ❌ not available on this node |

No end-to-end image build or container run executed here. Static validation only on this host.

## Validation performed

| Check | Result |
|---|---|
| `bash -n` on any shell scripts | ✅ |
| `yaml.safe_load(docker-compose.yml)` | ✅ |
| Service set vs `../vpipe/`: `validate`, `head`, `worker1`, `worker2` | ✅ |
| Image-name consistency (`sci-lammps` / `sci-lammps-deploy`) | ✅ |
| Dockerfile parses (10 steps, `FROM sci-hpc-base` resolves at build time) | ✅ |

## 2026-04-29 multi-node deployment verification update

**Status: ✅ verified multi-node MPI (4 ranks, "1 by 2 by 2" grid across 4 SLURM nodes)**

A 3-stage workflow variant (minimize → equilibrate → production with restart-file producer→data→consumer chain) was run at 4-node Ares SLURM 2026-04-29 with `mpirun -np 4 lmp_mpi`:

- EXIT=0, 59s elapsed.
- All 3 stages produced output: `melt_minimized.restart`, `melt_equilibrated.restart`, `melt_production.dat`, `melt_production.lammpstrj`.
- MPI processor grid "1 by 2 by 2" confirmed in `min.log` — true 4-rank multi-node distribution, not single-node-on-allocated-4.
- Workflow archive: `paper_widget/data/multinode_profile/LAMMPS/datalife_2026-04-21_4node/`.
- Workflow source: `hpc_workflows/runs/lammps/small_4node/`.

**Trace collection note**: `lmp` FPEs at startup when libmonitor (DataLife) is preloaded, regardless of MPI rank count or `MONITOR_SKIP_BINARIES` blacklist. This is the same class as the `gmx` × libmonitor SIGSEGV in biobb_wf_md_setup. Use **Darshan** instead of DataLife for LAMMPS I/O trace collection — Darshan's MPI-IO interception doesn't trip the FPE.

## What has **not** been validated (requires a docker-capable host)

- Actual image build (pulls `nvidia/cuda:12.6.0-devel-ubuntu24.04` and the LAMMPS develop branch).
- `docker compose run --rm validate`: 4-rank MPI run of `bench/in.lj` inside one container.
- `docker compose up head`: 3-way cluster MPI run across head + worker1 + worker2 over SSH.
