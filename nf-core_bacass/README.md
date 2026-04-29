# nf-core/bacass — bacterial whole-genome assembly

[nf-core/bacass](https://nf-co.re/bacass) is a Nextflow DSL2 pipeline for
bacterial WGS assembly + annotation. Per-process conda environments are
solved on first `--use-conda` run.

CPU-only test profile (`-profile test,conda`) consumes the bundled small
FASTQ subset and produces an assembly + annotation in roughly 30 min.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Builder image (`sci-nf-bacass`): Nextflow + Java 17 + Miniforge + nf-core/bacass v2.4.0. |
| `Dockerfile.deploy` | Runtime image (`sci-nf-bacass-deploy`) — copied conda + Nextflow + pipeline tree from the builder; ssh enabled for cluster mode. |
| `docker-compose.yml` | `validate` (single-node) and `head/worker1/worker2` (3-way fan-out) services. |
| `run_bacass.sh` | Driver: invokes `nextflow run … -profile test,conda` into a per-run output dir. |
| `VALIDATION.md` | Record of what's been verified vs. what still needs a docker-capable host. |

## Quick start

```bash
docker build -t sci-hpc-base    ../base
docker build -t sci-nf-bacass        -f Dockerfile        .
docker build -t sci-nf-bacass-deploy -f Dockerfile.deploy .
docker compose run --rm validate
```

For the 3-way cluster fan-out, use `docker compose up`.

## Bare-metal validation

This pipeline was profiled on Ares HPC at 4-node scale on 2026-04-28
under DataLife (libmonitor) — 282 blk_trace JSONs captured across
fastqc, BWA, SPAdes/Unicycler, prokka stages. See the
`hpc_workflows/runs/nf-core_bacass/small_4node/` benchmark directory and
`paper_widget/data/multinode_profile/nf-core_bacass/datalife_2026-04-21_4node/`.
