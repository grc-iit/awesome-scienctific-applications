# nf-core/createtaxdb — taxonomy database build (kraken2 / centrifuge / etc.)

[nf-core/createtaxdb](https://nf-co.re/createtaxdb) is a Nextflow DSL2 pipeline.
Per-process conda environments are solved on first `--use-conda` run.

CPU-only test profile (`-profile test,conda`) consumes the bundled small
test data and produces outputs under `outputs/`.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builder image (`sci-nf-createtaxdb`): Nextflow + Java 17 + Miniforge + nf-core/createtaxdb. |
| `Dockerfile.deploy` | Runtime image (`sci-nf-createtaxdb-deploy`); ssh enabled for cluster mode. |
| `docker-compose.yml` | `validate` (single-node) and `head/worker1/worker2` (3-way fan-out) services. |
| `run_createtaxdb.sh` | Driver: invokes `nextflow run … -profile test,conda` into a per-run output dir. |
| `VALIDATION.md` | Record of what's been verified vs. what still needs a docker-capable host. |

## Quick start

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-nf-createtaxdb        -f Dockerfile        .
docker build -t sci-nf-createtaxdb-deploy -f Dockerfile.deploy .
docker compose run --rm validate
```

## Bare-metal validation

Profiled on Ares HPC at 4-node SLURM under DataLife (libmonitor) on
2026-04-28 — **56 blk_trace JSONs captured**, 7252s elapsed. Source
benchmark: `hpc_workflows/runs/nf-core_createtaxdb/small_4node/`. Archive:
`paper_widget/data/multinode_profile/nf-core_createtaxdb/datalife_2026-04-21_4node/`.
