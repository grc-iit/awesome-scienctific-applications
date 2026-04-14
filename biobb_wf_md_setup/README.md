# biobb_wf_md_setup — BioExcel Building Blocks MD Setup

[biobb_wf_md_setup](https://github.com/bioexcel/biobb_wf_md_setup) is a
reference BioExcel Building Blocks (biobb) workflow that prepares a protein
for molecular dynamics simulation. This container reproduces the setup
pipeline as a 5-step Python driver:

1. Stage PDB
2. Fix side chains (`biobb_model`)
3. Generate topology via `pdb2gmx` (`biobb_gromacs` → GROMACS)
4. Define simulation box via `editconf` (GROMACS)
5. Solvate the system (GROMACS)

The container is **CPU-only**. GROMACS is installed from conda-forge
(`gromacs=2026`) because it is not available as a distro package. The shared
`sci-hpc-base` image is reused for MPI/SSH parity with the rest of the
repo. Within a single structure the pipeline is sequential, so cluster-level
parallelism is achieved by **sharding PDB inputs across workers** — the
multi-node target dispatches PDBs round-robin to `head/worker1/worker2` via
SSH.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access during the builder build (miniforge installer + RCSB PDB
  fetch + conda-forge package downloads).

---

## 1  Build

```bash
docker build -t sci-hpc-base           ../base
docker build -t sci-biobb-md-setup     .
docker build -t sci-biobb-md-setup-deploy -f Dockerfile.deploy .
```

The builder stage installs a dedicated conda env under `/opt/biobb-env`
(GROMACS 2026 + biobb + Python 3.10). Expect this step to take ~10-15 min
the first time.

---

## 2  Single-Node Run

The deploy image bundles `/opt/biobb-bench/1AKI.pdb` (lysozyme, 14 kB) for a
self-contained smoke test.

```bash
docker run --rm -v $(pwd)/output:/output sci-biobb-md-setup-deploy \
  /opt/run_md_setup.py /opt/biobb-bench/1AKI.pdb /output/1AKI
```

On success `output/1AKI/1AKI_solvate.gro` is produced and each step prints
`PASS`. Total runtime ≈ 3 s for 1AKI.

### Running on your own PDB

```bash
docker run --rm \
  -v /path/to/my_pdbs:/input:ro \
  -v $(pwd)/output:/output \
  sci-biobb-md-setup-deploy \
  /opt/run_md_setup.py /input/MY.pdb /output/MY
```

Some PDBs with non-standard residues will fail at `pdb2gmx` with the default
AMBER99SB-ILDN force field — this is expected behaviour, not a container
bug.

---

## 3  Multi-Node Run

The `run_batch.sh` driver shards a directory of PDB files round-robin
across a comma-separated host list, launching `run_md_setup.py` on each via
SSH.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network host \
  --name biobb-worker1 sci-biobb-md-setup-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v /path/to/pdbs:/input:ro \
  -v $(pwd)/output:/output \
  sci-biobb-md-setup-deploy \
  /opt/run_batch.sh /input /output head,worker1,worker2
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

The head container duplicates the bundled 1AKI.pdb into three tagged copies,
shards them across `head/worker1/worker2`, and collects the solvated outputs
on the shared `/output` volume. Expected tail:
`=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-biobb-md-setup`): miniforge + conda env with GROMACS + biobb; `COPY`s the two driver scripts into `/opt/`. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-biobb-md-setup-deploy`): Ubuntu 24.04 + baked conda env + drivers + SSH. |
| `docker-compose.yml` | `validate` (single-node smoke) and `head`/`worker1`/`worker2` (multi-node cluster over `mpi-net`). |
| `run_md_setup.py` | Per-PDB driver: runs the 5-step pipeline on one input PDB and exits 0 only if all five steps succeed. Installed at `/opt/run_md_setup.py` in both images. |
| `run_batch.sh` | Multi-PDB fan-out: shards a directory of PDBs round-robin across a comma-separated host list, invoking `run_md_setup.py` on each target via SSH. Installed at `/opt/run_batch.sh` in both images. |
| `README.md` | This file. |

---

## References

- Andrio, P., et al. (2019). "BioExcel Building Blocks, a software library
  for interoperable biomolecular simulation workflows." *Scientific Data*
  6, 169.
- https://github.com/bioexcel/biobb_wf_md_setup
