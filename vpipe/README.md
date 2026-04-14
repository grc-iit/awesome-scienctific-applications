# V-pipe — Virus NGS Pipeline

[V-pipe](https://github.com/cbg-ethz/V-pipe) is a Snakemake pipeline from
the Computational Biology Group at ETH Zürich for analysing next-
generation sequencing data from viral samples — QC, read alignment,
consensus calling, SNV calling, haplotype reconstruction. SARS-CoV-2 and
HIV are the two primary targets and ship with upstream test data.

The container is **CPU-only**. V-pipe is pinned to **v3.0.0** (Snakemake
7.32.4) because `load_configfile` was removed in Snakemake 8+, which the
v3.0.0 workflow still calls.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access both during the builder build (miniforge + Snakemake 7
  + V-pipe clone) and during **the first container run** (V-pipe's
  per-rule `--use-conda` environments are solved on first use; expect an
  extra 5-10 minutes of conda-forge/bioconda downloads on that first run,
  then cached in the `/opt/conda/envs/vpipe-tools` prefix).

---

## 1  Build

```bash
docker build -t sci-hpc-base    ../base
docker build -t sci-vpipe       .
docker build -t sci-vpipe-deploy -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

The deploy image ships `/opt/V-pipe/tests/data/{sars-cov-2,hiv}/` — two
upstream test datasets. The `/opt/run_vpipe.sh` driver:

1. Creates a fresh project directory under the path you give it.
2. Runs `init_project.sh` (generates default `config/`).
3. Symlinks the requested virus's test data as `samples/`.
4. Invokes `snakemake --cores $CORES --use-conda` on the V-pipe
   `Snakefile`.
5. Asserts at least one file was written under `results/`.

```bash
docker run --rm -v $(pwd)/output:/output sci-vpipe-deploy \
  /opt/run_vpipe.sh sars-cov-2 /output/run
```

Override `CORES` (default 2):

```bash
docker run --rm -e CORES=8 -v $(pwd)/output:/output sci-vpipe-deploy \
  /opt/run_vpipe.sh sars-cov-2 /output/run
```

Run HIV instead of SARS-CoV-2:

```bash
docker run --rm -v $(pwd)/output:/output sci-vpipe-deploy \
  /opt/run_vpipe.sh hiv /output/run
```

---

## 3  Multi-Node Run

V-pipe jobs are independent per sample set; the multi-node target runs
three different project directories on three nodes in parallel over SSH.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network host \
  --name vpipe-worker1 sci-vpipe-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v $(pwd)/output:/output \
  sci-vpipe-deploy bash -c '
    /opt/run_vpipe.sh sars-cov-2 /output/head &
    ssh worker1 "/opt/run_vpipe.sh hiv        /output/worker1" &
    ssh worker2 "/opt/run_vpipe.sh sars-cov-2 /output/worker2" &
    wait'
```

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

Expected tail: `=== SINGLE-NODE TEST PASSED ===`. The first run will also
take time solving V-pipe's per-rule conda envs.

### Validate multi-node

```bash
docker compose up --abort-on-container-exit --exit-code-from head head
```

The head container runs `sars-cov-2` locally and dispatches `hiv` to
worker1 and `sars-cov-2` to worker2 over SSH. Each must produce at least
one file under `results/`. Expected tail: `=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-vpipe`): miniforge + Snakemake 7.32.4 + V-pipe v3.0.0 source. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-vpipe-deploy`): Ubuntu 24.04 + baked Snakemake env + V-pipe source + driver + SSH. `/opt/conda` is preserved so Snakemake can keep materialising per-rule envs on first run. |
| `docker-compose.yml` | `validate` (single sars-cov-2 run) and `head`/`worker1`/`worker2` (three project dirs, sars-cov-2/hiv/sars-cov-2, fanned out over SSH). |
| `run_vpipe.sh` | Driver: `init_project.sh` + samples symlink + `snakemake --use-conda`. Respects `CORES` env var. Installed at `/opt/run_vpipe.sh`. |
| `README.md` | This file. |
| `VALIDATION.md` | Record of what has and has not been tested. |

---

## References

- Posada-Céspedes, S., et al. (2021). "V-pipe: a computational pipeline
  for assessing viral genetic diversity from high-throughput sequencing
  data." *Bioinformatics* 37(12), 1673-1680.
- https://github.com/cbg-ethz/V-pipe
