# Gray-Scott ParaView — Visualization for Reaction-Diffusion Simulations

[ParaView](https://www.paraview.org) is a parallel visualization application
from Kitware. This container builds ParaView 5.13 with ADIOS2, Fides, MPI,
Catalyst, and Python support for visualizing Gray-Scott reaction-diffusion
simulation data.

Data flows from the Gray-Scott simulation through ADIOS2 (BP5 files or SST
streams) into ParaView's VTK pipeline via the Fides reader. Catalyst enables
in-situ visualization without writing intermediate files.

```
Gray-Scott Sim  --(ADIOS2 BP5/SST)-->  Fides Reader  -->  ParaView VTK Pipeline  -->  Rendered Output
```

---

## Prerequisites

- NVIDIA GPU (optional — CPU offscreen rendering is supported)
- Docker with NVIDIA Container Toolkit (for GPU rendering)
- Base image `sci-hpc-base` built from `../base/Dockerfile`

---

## 1  Build

```bash
# Build the base image (CUDA 12.6 + OpenMPI + HDF5)
docker build -t sci-hpc-base ../base

# Build the full ParaView image (compiles ADIOS2, Catalyst, ParaView)
docker build -t sci-paraview .

# Build the lightweight deployment image
docker build -t sci-paraview-deploy -f Dockerfile.deploy .
```

---

## 2  Single-Node Run

### Batch rendering with pvbatch

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  sci-paraview-deploy \
  pvbatch --force-offscreen-rendering -c "
    from paraview.simple import *
    reader = FidesReader(FileName='/data/gs.bp')
    reader.UpdatePipeline()
    display = Show(reader)
    display.SetRepresentationType('Volume')
    ColorBy(display, ('POINTS', 'U'))
    view = GetActiveView()
    view.ViewSize = [800, 600]
    Render()
    SaveScreenshot('/output/gray_scott.png')
  "
```

### Parallel pvbatch with MPI

```bash
docker run --gpus all --rm \
  -v $(pwd)/output:/output \
  -v $(pwd)/data:/data \
  sci-paraview-deploy \
  mpirun -np 4 --oversubscribe --allow-run-as-root \
    pvbatch --force-offscreen-rendering /data/render_script.py
```

### Reading ADIOS2 BP5 data

ParaView reads ADIOS2 BP5 files through the **Fides reader**. Create a Fides
JSON schema describing the data layout, then open it in ParaView:

```python
from paraview.simple import *

# Fides reader for ADIOS2 BP5 files
reader = FidesReader(FileName='gs.bp')
reader.UpdatePipeline()

# Volume render the U concentration field
display = Show(reader)
display.SetRepresentationType('Volume')
ColorBy(display, ('POINTS', 'U'))
Render()
```

### In-situ with ADIOS2 SST

Run the Gray-Scott simulation and ParaView visualization simultaneously:

```bash
# Terminal 1: Gray-Scott simulation writing via SST
docker run --gpus all --rm --network host \
  sci-grayscott \
  mpirun -np 4 --allow-run-as-root adios2_simulations/gray-scott gs.xml settings.json

# Terminal 2: ParaView reading via SST
docker run --gpus all --rm --network host \
  -v $(pwd)/output:/output \
  sci-paraview-deploy \
  pvbatch --force-offscreen-rendering /scripts/sst_reader.py
```

---

## 3  Multi-Node Run

### Start workers

```bash
# worker1.cluster.local
docker run --gpus all -d --rm \
  --hostname worker1 --network host \
  -v $(pwd)/output:/output \
  --name pv-worker1 sci-paraview-deploy /usr/sbin/sshd -D

# worker2.cluster.local
docker run --gpus all -d --rm \
  --hostname worker2 --network host \
  -v $(pwd)/output:/output \
  --name pv-worker2 sci-paraview-deploy /usr/sbin/sshd -D
```

### Run parallel pvbatch from head node

```bash
docker run --gpus all --rm \
  --network host \
  -v $(pwd)/output:/output \
  -v $(pwd)/data:/data \
  sci-paraview-deploy \
  mpirun -np 6 --allow-run-as-root \
    --host $(hostname):2,worker1.cluster.local:2,worker2.cluster.local:2 \
    pvbatch --force-offscreen-rendering /data/render_script.py
```

ParaView distributes the data across ranks automatically for parallel
rendering.

---

## 4  Simulated Cluster Validation

### Validate single-node

```bash
docker compose run --rm validate
```

The `validate` service runs three tests:
1. **pvbatch rendering** — renders a Wavelet source to PNG
2. **ADIOS2 BP5 write + Fides read** — writes a BP5 file, reads it with FidesReader
3. **MPI pvbatch** — parallel rendering with 2 MPI ranks

Expected: all three tests print OK, ending with `SINGLE-NODE TEST PASSED`.

### Validate multi-node

```bash
docker compose up --abort-on-container-exit --exit-code-from head head
```

The head node runs `pvbatch` across 3 MPI ranks (head + worker1 + worker2),
renders a Wavelet source, and saves a screenshot.

Expected: `CLUSTER TEST PASSED`.

### Cleanup

```bash
docker compose down
```

---

## Enabled Features

| Feature | Details |
|---------|---------|
| Qt6 GUI | `paraview` client for interactive visualization |
| ADIOS2 2.10.2 | BP5 (default), BP4, SST, HDF5 engines |
| Fides | Schema-driven ADIOS2 reader for VTK pipeline |
| MPI | Parallel rendering via `pvserver` / `pvbatch` |
| Catalyst 2.0 | In-situ analysis API (libcatalyst) |
| Python 3.12 | `pvpython`, `pvbatch`, `paraview.simple` scripting |

---

## References

- ParaView Documentation: https://docs.paraview.org
- ADIOS2 Gray-Scott Tutorial: https://adios2.readthedocs.io/en/latest/tutorials/gray_scott.html
- Fides Reader: https://fides.readthedocs.io
- Catalyst In-Situ: https://catalyst-in-situ.readthedocs.io
