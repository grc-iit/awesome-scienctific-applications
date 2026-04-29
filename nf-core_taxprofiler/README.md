# nf-core/taxprofiler — metagenomic taxonomic classification

[nf-core/taxprofiler](https://nf-co.re/taxprofiler) is a Nextflow DSL2 pipeline.
Per-process conda environments are solved on first `--use-conda` run.

CPU-only test profile (`-profile test,conda`) consumes the bundled small
test data and produces outputs under `outputs/`.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builder image (`sci-nf-taxprofiler`): Nextflow + Java 17 + Miniforge + nf-core/taxprofiler. |
| `Dockerfile.deploy` | Runtime image (`sci-nf-taxprofiler-deploy`); ssh enabled for cluster mode. |
| `docker-compose.yml` | `validate` (single-node) and `head/worker1/worker2` (3-way fan-out) services. |
| `run_taxprofiler.sh` | Driver: invokes `nextflow run … -profile test,conda` into a per-run output dir. |
| `VALIDATION.md` | Record of what's been verified vs. what still needs a docker-capable host. |

## Quick start

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-nf-taxprofiler        -f Dockerfile        .
docker build -t sci-nf-taxprofiler-deploy -f Dockerfile.deploy .
docker compose run --rm validate
```

## Bare-metal validation

Profiled on Ares HPC at 4-node SLURM under DataLife (libmonitor) on
2026-04-28 — **72 blk_trace JSONs captured**, 634s elapsed. Source
benchmark: `hpc_workflows/runs/nf-core_taxprofiler/small_4node/`. Archive:
`paper_widget/data/multinode_profile/nf-core_taxprofiler/datalife_2026-04-21_4node/`.
