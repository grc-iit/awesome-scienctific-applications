# Montage — Astronomical Image Mosaic Engine

[Montage](http://montage.ipac.caltech.edu/) is a toolkit for assembling FITS
astronomical images into custom mosaics, developed at Caltech/IPAC. This
container builds the Montage C toolkit from source and pre-stages a small
2MASS J-band benchmark region (M17, ~4 tiles) for offline self-validation.

Montage is **CPU-only** — no GPU required — but the shared base image
`sci-hpc-base` is reused for a consistent MPI/SSH runtime. `mProjExec` is
embarrassingly parallel per image and is fanned out over SSH in the
multi-node target.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access during the builder image build (Montage downloads 2MASS
  tiles via its own `mArchiveExec`).

---

## 1  Build

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-montage .
docker build -t sci-montage-deploy -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

The deploy image ships `/opt/montage-bench/` with the M17 FITS tiles and a
target `region.hdr`. The 10-step pipeline driver is `/opt/run_mosaic.sh`.

```bash
docker run --rm -v $(pwd)/output:/output sci-montage-deploy \
  /opt/run_mosaic.sh \
      /opt/montage-bench/raw_images \
      /opt/montage-bench/region.hdr \
      /output
```

Stages: `mImgtbl → mProjExec → mImgtbl → mOverlaps → mDiffExec → mFitExec →
mBgModel → mBgExec → mImgtbl → mAdd`. On success `output/mosaic.fits` is
produced and every stage prints `stat="OK"`.

### Running on your own FITS data

```bash
docker run --rm \
  -v /path/to/my_fits:/input:ro \
  -v /path/to/region.hdr:/input/region.hdr:ro \
  -v $(pwd)/output:/output \
  sci-montage-deploy \
  /opt/run_mosaic.sh /input /input/region.hdr /output
```

---

## 3  Multi-Node Run

`mProjExec` is embarrassingly parallel. The driver accepts a fourth argument
— a comma-separated host list — and splits the image table across hosts,
launching `mProjExec` on each via SSH. Later stages run on the head node
against the shared `/output` volume.

### Worker nodes

```bash
# On each worker (repeat with different --hostname)
docker run -d --rm \
  --hostname worker1 --network host \
  --name montage-worker1 \
  sci-montage-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v $(pwd)/output:/output \
  sci-montage-deploy \
  /opt/run_mosaic.sh \
      /opt/montage-bench/raw_images \
      /opt/montage-bench/region.hdr \
      /output \
      head,worker1,worker2
```

Add more worker hostnames to the comma list to scale.

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

The head container blocks on worker1/worker2 health (SSH on port 22), then
fans out `mProjExec` across the three hostnames on the `mpi-net` overlay
network. Expected tail: `=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-montage`): clones & compiles Montage, pre-stages the 2MASS M17 benchmark via `mArchiveExec`, and `COPY`s the pipeline driver. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-montage-deploy`): Ubuntu 24.04 + Montage binaries + benchmark inputs + driver + SSH. |
| `docker-compose.yml` | `validate` (single-node smoke) and `head`/`worker1`/`worker2` (multi-node cluster over `mpi-net`). |
| `run_mosaic.sh` | 10-step mosaic driver (mImgtbl → mProjExec → ... → mAdd). If a comma-separated host list is passed as `$4`, `mProjExec` is fanned out over SSH using header-aware sharding of the Montage image table. Installed at `/opt/run_mosaic.sh` in both images. |
| `README.md` | This file. |

---

## References

- Jacob, J.C., et al. (2009). "Montage: a grid portal and software toolkit
  for science-grade astronomical image mosaicking." *IJCSE* 4(2), 73-87.
- https://github.com/Caltech-IPAC/Montage
