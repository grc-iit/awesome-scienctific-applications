# nf-core/proteinfold — AlphaFold2 / Colabfold protein structure prediction

[nf-core/proteinfold](https://nf-co.re/proteinfold) is a Nextflow DSL2 pipeline.
Per-process conda environments are solved on first `--use-conda` run.

CPU-only test profile (`-profile test,conda`) consumes the bundled small
test data and produces outputs under `outputs/`.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builder image (`sci-nf-proteinfold`): Nextflow + Java 17 + Miniforge + nf-core/proteinfold. |
| `Dockerfile.deploy` | Runtime image (`sci-nf-proteinfold-deploy`); ssh enabled for cluster mode. |
| `docker-compose.yml` | `validate` (single-node) and `head/worker1/worker2` (3-way fan-out) services. |
| `run_proteinfold.sh` | Driver: invokes `nextflow run … -profile test,conda` into a per-run output dir. |
| `VALIDATION.md` | Record of what's been verified vs. what still needs a docker-capable host. |

## Quick start

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-nf-proteinfold        -f Dockerfile        .
docker build -t sci-nf-proteinfold-deploy -f Dockerfile.deploy .
docker compose run --rm validate
```

## Bare-metal validation

Profiled on Ares HPC at 4-node SLURM under DataLife (libmonitor) on
2026-04-28 — **12 blk_trace JSONs captured**, 94s elapsed. Source
benchmark: `hpc_workflows/runs/nf-core_proteinfold/small_4node/`. Archive:
`paper_widget/data/multinode_profile/nf-core_proteinfold/datalife_2026-04-21_4node/`.
