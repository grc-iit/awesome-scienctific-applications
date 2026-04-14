# metaGEM — Genome-Scale Metabolic Reconstruction from Metagenomes

[metaGEM](https://github.com/franciscozorrilla/metaGEM) is a Snakemake
workflow for recovering metagenome-assembled genomes and reconstructing
genome-scale metabolic models from shotgun metagenomic reads. Typical
stages: qfilter → assembly (megahit) → binning (concoct/maxbin/metabat)
→ refinement → GEM reconstruction (COBRApy) → community simulation
(SMETANA).

This container focuses on the **qfilter** stage (fastp quality filtering),
which is metaGEM's default target and exercises the full Snakemake DAG
setup without pulling in the multi-tool downstream stack. Running
downstream targets is a matter of passing extra rule names to
`run_metagem.sh`.

CPU-only.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access during the builder build (miniforge + Snakemake 9 +
  fastp from conda-forge/bioconda + metaGEM clone) and during the first
  container run if you do not supply your own data (metaGEM's
  `downloadToy` rule fetches a small toy dataset on demand).

---

## 1  Build

```bash
docker build -t sci-hpc-base        ../base
docker build -t sci-metagem         .
docker build -t sci-metagem-deploy  -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

The driver is `/opt/run_metagem.sh <workdir>`. It:

1. Creates the metaGEM directory layout under `<workdir>`.
2. Writes a `config.yaml` with `root: <workdir>`.
3. If `<workdir>/dataset/` has no paired FASTQs, it calls metaGEM's
   upstream `downloadToy` rule to fetch toy samples.
4. Runs `snakemake qfilter --cores $CORES --configfile <workdir>/config.yaml`.
5. Asserts at least one `*_R1.fastq.gz` appears under `<workdir>/qfiltered/`.

```bash
docker run --rm -v $(pwd)/output:/output sci-metagem-deploy \
  /opt/run_metagem.sh /output/run
```

### Bringing your own FASTQ data

Place paired-end FASTQ files under the workdir before invoking the
driver (it will skip `downloadToy` automatically):

```
<workdir>/dataset/sample1/sample1_R1.fastq.gz
<workdir>/dataset/sample1/sample1_R2.fastq.gz
<workdir>/dataset/sample2/sample2_R1.fastq.gz
<workdir>/dataset/sample2/sample2_R2.fastq.gz
...
```

### Running downstream stages

```bash
# After qfilter, continue through assembly + binning
docker run --rm -v $(pwd)/output:/output sci-metagem-deploy \
  /opt/run_metagem.sh /output/run megahit concoct metabat
```

Downstream rules may require additional tool conda envs; metaGEM's
documentation covers this in detail.

---

## 3  Multi-Node Run

Each metaGEM project directory is independent. Multi-node parallelism is
expressed by running separate qfilter projects on each node over SSH.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network host \
  --name metagem-worker1 sci-metagem-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v $(pwd)/output:/output \
  sci-metagem-deploy bash -c '
    /opt/run_metagem.sh /output/head &
    ssh worker1 "/opt/run_metagem.sh /output/worker1" &
    ssh worker2 "/opt/run_metagem.sh /output/worker2" &
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

Each of head/worker1/worker2 runs its own qfilter project. Expected
tail: `=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-metagem`): miniforge + Snakemake 9.18.2 + a `metagem` named conda env with fastp; clones metaGEM and applies the conda-activate patch. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-metagem-deploy`): Ubuntu 24.04 + baked conda envs + metaGEM source + driver + SSH. |
| `docker-compose.yml` | `validate` (single qfilter run) and `head`/`worker1`/`worker2` (three independent qfilter projects fanned out over SSH). |
| `run_metagem.sh` | Driver: sets up workdir layout, rewrites metaGEM's `/path/to/project/...` placeholders, auto-downloads toy data if missing, runs `snakemake qfilter`. Respects `CORES` env var. Installed at `/opt/run_metagem.sh`. |
| `metagem-conda-activate.patch` | Patch applied during image build. Rewrites metaGEM's `source activate ...` calls (pre-4.4 conda API) to `eval "$(conda shell.bash hook)" && conda activate ...`; without this the Snakefile rules fail on newer conda installs. |
| `README.md` | This file. |
| `VALIDATION.md` | Record of what has and has not been tested. |

---

## References

- Zorrilla, F., et al. (2021). "metaGEM: reconstruction of genome scale
  metabolic models directly from metagenomes." *Nucleic Acids Research*
  49(21), e126.
- https://github.com/franciscozorrilla/metaGEM
