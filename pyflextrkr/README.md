# PyFLEXTRKR — Python FLEXible object TRacKeR

[PyFLEXTRKR](https://github.com/FlexTRKR/PyFLEXTRKR) is a Python framework
for tracking atmospheric features — mesoscale convective systems,
convective cells, cyclones, etc. — across time-sequenced gridded fields.
It is developed primarily at PNNL and backs several observational/model
MCS tracking workflows.

The container is **CPU-only**. PyFLEXTRKR's native parallelism is via Dask,
but the Dask local-cluster mode has a known HDF5 concurrent-access bug; the
bare-metal benchmark on which this container is based fell back to
serial mode (`run_parallel=0, nprocesses=1`), and the `run_demo.sh`
wrapper here does the same by passing `-n 1` to the upstream demo runner.

The self-test exercises `demo_mcs_tbpf_idealized` — the smallest upstream
demo case — which downloads a ~1-2 MB idealized Tb+precipitation dataset
and runs the full 9-step MCS tracking pipeline.

---

## Prerequisites

- Docker
- Base image `sci-hpc-base` built from `../base/Dockerfile`
- Internet access during the builder build (PyFLEXTRKR clone + pip deps)
  **and at container run time** (the demo runner downloads sample data on
  first use from `portal.nersc.gov`).

---

## 1  Build

```bash
docker build -t sci-hpc-base            ../base
docker build -t sci-pyflextrkr          .
docker build -t sci-pyflextrkr-deploy   -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

```bash
docker run --rm -v $(pwd)/output:/output sci-pyflextrkr-deploy \
  /opt/run_demo.sh demo_mcs_tbpf_idealized /output/data
```

The wrapper invokes `python tests/run_demo_tests.py --demos <demo>
--data-root <data_root> -n 1`, so the entire upstream demo harness runs
(download → config templating → tracking → output validation).

### Other demos

The upstream list (add `--with-plots` for ffmpeg animations):

```bash
docker run --rm sci-pyflextrkr-deploy \
  python /opt/PyFLEXTRKR/tests/run_demo_tests.py --list
```

Run a different case:

```bash
docker run --rm -v $(pwd)/output:/output sci-pyflextrkr-deploy \
  /opt/run_demo.sh demo_cell_nexrad /output/data
```

---

## 3  Multi-Node Run

Since the pipeline's Dask parallelism is disabled for correctness reasons
(see HDF5 note above), cluster-level parallelism is achieved by **running
independent demo cases on each worker over SSH**. This proves the
SSH/network topology is live without fighting the HDF5 bug.

### Worker nodes

```bash
docker run -d --rm --hostname worker1 --network host \
  --name pyflextrkr-worker1 sci-pyflextrkr-deploy /usr/sbin/sshd -D
```

### Head node

```bash
docker run --rm --network host \
  -v $(pwd)/output:/output \
  sci-pyflextrkr-deploy bash -c '
    /opt/run_demo.sh demo_mcs_tbpf_idealized /output/head &
    ssh worker1 "/opt/run_demo.sh demo_mcs_tbpf_idealized /output/worker1" &
    ssh worker2 "/opt/run_demo.sh demo_mcs_tbpf_idealized /output/worker2" &
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

The head container starts the demo on itself and on both workers in
parallel over SSH, then asserts that each node produced its own `stats/`
directory. Expected tail: `=== CLUSTER TEST PASSED ===`.

---

## Files in this directory

| File | Purpose |
|------|---------|
| `Dockerfile` | Builder image (`sci-pyflextrkr`): Python 3.10 venv + PyFLEXTRKR editable install from upstream `main`. |
| `Dockerfile.deploy` | Minimal runtime image (`sci-pyflextrkr-deploy`): Ubuntu 24.04 + baked venv + upstream source tree (needed for demo runner and config templates) + SSH. |
| `docker-compose.yml` | `validate` (single demo, serial) and `head`/`worker1`/`worker2` (three parallel demo runs over SSH). |
| `run_demo.sh` | Wrapper around `tests/run_demo_tests.py` that forces `-n 1` (serial) and asserts a non-empty `stats/` directory is produced. Installed at `/opt/run_demo.sh`. |
| `README.md` | This file. |
| `VALIDATION.md` | Record of what has and has not been tested. |

---

## References

- Feng, Z., et al. (2023). "PyFLEXTRKR: a flexible feature tracking Python
  software for convective cloud analysis." *Geoscientific Model
  Development* 16, 2753-2776.
- https://github.com/FlexTRKR/PyFLEXTRKR
