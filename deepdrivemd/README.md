# DeepDriveMD — Adaptive Biomolecular Simulation Framework

[DeepDriveMD](https://github.com/DeepDriveMD/DeepDriveMD-pipeline) is a
RADICAL-EnTK workflow that interleaves **molecular dynamics**,
**representation learning**, **model selection**, and an **agent** that
steers subsequent rounds of sampling based on learned representations.
Each iteration executes those four stages in sequence; the full loop
runs for `max_iteration` iterations.

This container packages the DDMD pipeline plus its RADICAL stack and
dependencies. The four stages all use `/bin/echo` placeholders rather
than real executables — this mirrors the bare-metal smoke test, which
validated that the framework itself (config parsing, stage sequencing,
iterative loop) executes end-to-end without requiring GPU nodes. Re-wire
the YAML's `*_stage.executable` entries to a real OpenMM driver and add
GPU reservations to `docker-compose.yml` for production use.

CPU-only as shipped.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access during the builder build (pip install of RADICAL,
  OpenMM, MDAnalysis, MD-tools; clone of DeepDriveMD; fetch of
  `1FME.pdb` from RCSB).

---

## 1  Build

```bash
docker build -t sci-hpc-base            ../base
docker build -t sci-deepdrivemd         .
docker build -t sci-deepdrivemd-deploy  -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

The driver `/opt/run_ddmd.sh <experiment_dir> [<max_iter> [<num_tasks>]]`:

1. Renders `/opt/deepdrivemd.template.yaml` with the requested
   `experiment_directory`, `max_iteration`, and `num_tasks`.
2. Points `RADICAL_BASE` at the experiment dir so each run is
   self-contained (no pollution of `~/radical.pilot.sandbox`).
3. Invokes `python -m deepdrivemd.deepdrivemd -c <cfg>`.
4. Asserts at least one `stage*` sub-directory is created.

```bash
docker run --rm -v $(pwd)/output:/output sci-deepdrivemd-deploy \
  /opt/run_ddmd.sh /output/exp_small 1 1
```

Matches the bare-metal smoke config: `max_iteration=1`, 1 MD task, all
executables `/bin/echo`.

### Larger run

```bash
# 2 iterations, 4 MD tasks per iteration — still placeholder /bin/echo
docker run --rm -v $(pwd)/output:/output sci-deepdrivemd-deploy \
  /opt/run_ddmd.sh /output/exp_medium 2 4
```

### Production MD

Replace `molecular_dynamics_stage.executable` in
`/opt/deepdrivemd.template.yaml` with a real OpenMM driver (e.g.
`/opt/DeepDriveMD/examples/bba/md.py` adapted to your force field) and
re-run. This requires GPU nodes.

---

## 3  Multi-Node Run

RADICAL-EnTK has no first-class MPI-style cross-node primitive in
`local.localhost` schema; cluster-level parallelism here is expressed
as **independent experiments on each worker**, fanned out over SSH.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network host \
  --name ddmd-worker1 sci-deepdrivemd-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v $(pwd)/output:/output \
  sci-deepdrivemd-deploy bash -c '
    /opt/run_ddmd.sh /output/head 1 1 &
    ssh worker1 "/opt/run_ddmd.sh /output/worker1 1 1" &
    ssh worker2 "/opt/run_ddmd.sh /output/worker2 2 4" &
    wait'
```

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

Expected tail: `=== SINGLE-NODE TEST PASSED ===`.

### Validate multi-node

```bash
docker compose up --abort-on-container-exit --exit-code-from head head
```

Each of head/worker1/worker2 runs its own DDMD experiment. `worker2`
runs a longer config (2 iterations × 4 tasks) to prove variable
iteration counts. Expected tail: `=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-deepdrivemd`): Python venv with RADICAL-EnTK/Pilot/Utils, OpenMM 8.5, MDAnalysis, MD-tools, relaxed h5py/PyYAML; clones DeepDriveMD + applies `self.cfg` patch; embeds 1FME as benchmark PDB. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-deepdrivemd-deploy`): Ubuntu 24.04 + baked venv + DDMD source + template + driver + SSH. |
| `docker-compose.yml` | `validate` (1 iter × 1 task) and `head`/`worker1`/`worker2` (three independent experiments, worker2 larger). |
| `run_ddmd.sh` | Driver: renders the YAML template, sets `RADICAL_BASE` to the experiment dir, runs `python -m deepdrivemd.deepdrivemd`, asserts `stage*` dirs are produced. Installed at `/opt/run_ddmd.sh`. |
| `deepdrivemd.template.yaml` | Pipeline YAML template with `__EXPERIMENT_DIR__`, `__MAX_ITER__`, `__NUM_TASKS__` placeholders. All four stages use `/bin/echo` — swap in real executables for production. Installed at `/opt/deepdrivemd.template.yaml`. |
| `deepdrivemd-selfcfg.patch` | Patch applied during image build. Fixes `cfg.aggregation_stage` / `cfg.machine_learning_stage` references to `self.cfg.*` in `deepdrivemd/deepdrivemd.py` (a regression in v0.0.2); without it the pipeline manager raises `NameError`. |
| `README.md` | This file. |
| `VALIDATION.md` | Record of what has and has not been tested. |

---

## References

- Lee, H., et al. (2019). "DeepDriveMD: Deep-Learning Driven Adaptive
  Molecular Simulations for Protein Folding." *DLS @ SC19*.
- https://github.com/DeepDriveMD/DeepDriveMD-pipeline
- https://radical-cybertools.github.io/entk/
