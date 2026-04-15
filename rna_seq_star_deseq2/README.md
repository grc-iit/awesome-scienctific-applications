# rna-seq-star-deseq2 — RNA-seq Differential Expression with STAR + DESeq2

[rna-seq-star-deseq2](https://github.com/snakemake-workflows/rna-seq-star-deseq2)
is a reference Snakemake workflow maintained by the Snakemake community
for bulk RNA-seq differential expression: adapter trimming (fastp) →
genome download (Ensembl) → STAR index → STAR alignment → featureCounts
→ DESeq2 PCA + diffexp tables → MultiQC report.

CPU-only. This container pins the workflow to **v2.2.0** and Snakemake
to **9.18.2**; per-rule tool envs (STAR, samtools, DESeq2, multiqc, …)
are materialised on first run via `--use-conda`.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access both during the builder build (miniforge + Snakemake 9
  + workflow clone) and **during the first container run** (the
  `--use-conda` envs are downloaded on demand; expect an extra
  ~10-15 min of solves on first `validate`, cached under
  `/opt/conda/envs/rnaseq-tools`).

---

## 1  Build

```bash
docker build -t sci-hpc-base                    ../base
docker build -t sci-rna-seq-star-deseq2         .
docker build -t sci-rna-seq-star-deseq2-deploy  -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

The deploy image bundles a 4-sample S. cerevisiae benchmark under
`/opt/rnaseq-bench/` (~17 MB). The driver:

1. Stages `config.yaml`, `samples.tsv`, `units.tsv` into the requested
   workdir and rewrites paths to absolute.
2. Invokes `snakemake --cores $CORES --use-conda` on the workflow's
   Snakefile.
3. Asserts a diffexp table and STAR BAMs are produced.

```bash
docker run --rm -v $(pwd)/output:/output sci-rna-seq-star-deseq2-deploy \
  /opt/run_rnaseq.sh /output/run
```

Override `CORES` (default 2):

```bash
docker run --rm -e CORES=8 -v $(pwd)/output:/output sci-rna-seq-star-deseq2-deploy \
  /opt/run_rnaseq.sh /output/run
```

### Bringing your own data

Pre-populate the workdir with `samples.tsv`, `units.tsv`, and a
`config.yaml`; the driver only stages the bundled benchmark if the
workdir is empty.

---

## 3  Multi-Node Run

Each project directory runs independently. The multi-node target runs
three separate project dirs on three nodes in parallel over SSH.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network host \
  --name rnaseq-worker1 sci-rna-seq-star-deseq2-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v $(pwd)/output:/output \
  sci-rna-seq-star-deseq2-deploy bash -c '
    /opt/run_rnaseq.sh /output/head &
    ssh worker1 "/opt/run_rnaseq.sh /output/worker1" &
    ssh worker2 "/opt/run_rnaseq.sh /output/worker2" &
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

Each of head/worker1/worker2 runs its own project directory; success
requires a `*.diffexp.symbol.tsv` on every node. Expected tail:
`=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-rna-seq-star-deseq2`): miniforge + Snakemake 9.18.2 + workflow v2.2.0 + bundled benchmark. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-rna-seq-star-deseq2-deploy`): Ubuntu 24.04 + baked Snakemake env + workflow + bench + driver + SSH. |
| `docker-compose.yml` | `validate` (single project dir) and `head`/`worker1`/`worker2` (three independent projects fanned out over SSH). |
| `run_rnaseq.sh` | Driver: stages config + samples + units into workdir, rewrites paths, invokes `snakemake --use-conda`, asserts diffexp + STAR BAMs appear. Respects `CORES` env var. Installed at `/opt/run_rnaseq.sh`. |
| `bench/` | 4-sample S. cerevisiae benchmark. `ngs-test-data/reads/*.fq` (≈17 MB paired-end FASTQs) plus `samples.tsv` / `units.tsv` / `config.yaml` copied from the upstream `config_basic/` preset. Installed at `/opt/rnaseq-bench/` in both images. |
| `README.md` | This file. |
| `VALIDATION.md` | Record of what has and has not been tested. |

---

## References

- Köster, J. & Rahmann, S. (2012). "Snakemake — a scalable
  bioinformatics workflow engine." *Bioinformatics* 28(19), 2520-2522.
- https://github.com/snakemake-workflows/rna-seq-star-deseq2
