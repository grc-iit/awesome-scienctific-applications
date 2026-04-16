# Gray-Scott ParaView — In-Situ & In-Transit Visualization

[ParaView](https://www.paraview.org) is a parallel visualization application
from Kitware. This repo builds ParaView 5.13 with ADIOS2, Fides, MPI, Catalyst,
and Python support, and ships two reference workflows for visualizing the
[Gray-Scott](https://adios2.readthedocs.io/en/latest/tutorials/gray_scott.html)
reaction-diffusion simulation:

| Workflow | Directory | Coupling | Data path |
|---|---|---|---|
| **In-situ** | [`catalyst_gray_scott/`](catalyst_gray_scott) | Same process, zero-copy | ADIOS2 inline engine → Fides → Catalyst (in-process) → ParaView Live |
| **In-transit** | [`insitu_agent/`](insitu_agent) | Separate processes, TCP streaming | ADIOS2 SST engine → Fides reader → pvserver → GUI / MCP / AI agent |

Both share the same Fides schema (`gs-fides.json`) that maps the U/V scalar
fields onto a VTK Cartesian grid — that is the common glue between ADIOS2 and
ParaView's VTK pipeline.

```
Gray-Scott Sim ──(ADIOS2 BP5 / SST / Inline)──► Fides Reader ──► ParaView VTK Pipeline ──► Rendered Output
```

---

## Prerequisites

- NVIDIA GPU (optional — CPU offscreen rendering works)
- Docker with NVIDIA Container Toolkit, **or** a Spack install of ParaView 5.13.3
- Base image `sci-hpc-base` built from `../base/Dockerfile` (for the Docker path)

ParaView 5.13.3 requires **Python 3.11 or 3.12** (3.14 is incompatible and will
segfault during Catalyst init).

---

## 1  Build

### Docker

```bash
docker build -t sci-hpc-base ../base
docker build -t sci-paraview .
docker build -t sci-paraview-deploy -f Dockerfile.deploy .
```

### Spack (bare-metal / HPC)

```bash
# Cluster (Ares) — headless OSMesa build
spack install paraview@5.13.3 +adios2 +fides +mpi +libcatalyst +python ~qt \
    ^python@3.12 ^py-mpi4py ^hdf5@1.12.3 ^osmesa

# Workstation — Qt GUI build
spack install paraview@5.13.3 +qt +adios2 +fides +mpi +libcatalyst +python \
    ^python@3.12 ^py-mpi4py ^hdf5@1.12.3
```

---

## 2  Choose Your Workflow

### A. In-situ with Catalyst — [`catalyst_gray_scott/`](catalyst_gray_scott)

The simulation and ParaView pipeline run **in the same MPI job**. ADIOS2's
inline/Hermes plugin passes raw data pointers to Fides, which feeds Catalyst,
which executes a user Python pipeline every timestep. Catalyst Live lets you
attach a remote ParaView GUI.

**When to use:** tight-loop extract generation, highest throughput, no
interactivity requirements.

```bash
# Env setup
spack load paraview@5.13.3
export CATALYST_IMPLEMENTATION_NAME=paraview
export CATALYST_IMPLEMENTATION_PATHS=$(spack location -i paraview@5.13.3)/lib/catalyst

# Run — sim + vis in one call
mpirun -n 4 adios2-gray-scott settings.json
```

Key files:
- `adios2.xml` — `Plugin` engine (hermes) with `DataModel` + `Script` parameters
- `catalyst.py` — the ParaView pipeline Catalyst executes each step
  (sets `EnableCatalystLive=1` so a GUI can attach)
- `setting.json` — sim params, points `adios_config` at the inline XML

### B. In-transit with ADIOS2 SST + AI agent — [`insitu_agent/`](insitu_agent)

The simulation writes to an **SST stream** over TCP; a separate `pvpython`
bridge pulls one timestep at a time into a running `pvserver`, which both the
ParaView GUI and an **MCP server** can connect to. An LLM agent (OpenAI /
Anthropic) drives the visualization through MCP tools: pause/advance the
stream, create isosurfaces/slices, capture screenshots.

**When to use:** human-in-the-loop or AI-in-the-loop exploration; sim and vis
on different nodes; you need the simulation to never block on rendering
(`QueueFullPolicy=Discard`).

```bash
# Terminal 1 — shared pvserver
pvserver --multi-clients --server-port=11111

# Terminal 2 — Gray-Scott (SST writer)
mpirun -n 4 adios2-gray-scott settings-staging.json

# Terminal 3 — streaming bridge (SST reader → pvserver)
pvpython insitu_streaming.py -j gs-fides.json -b gs.bp \
    --staging --server localhost --port 11111 --paused

# Terminal 4 — AI agent (launches MCP server internally)
export ANTHROPIC_API_KEY=sk-ant-...
python insitu_agent.py --provider anthropic --model claude-sonnet-4-6
```

Key files:
- `adios2-sst.xml` — `SST` engine, `QueueLimit=3`, `QueueFullPolicy=Discard`,
  `DataTransport=WAN`
- `insitu_streaming.py` — pvpython bridge, exposes pause/advance via a
  control file
- `insitu_mcp_server.py` + `insitu_agent.py` — MCP tools and LLM driver
- `settings-staging.json` — sim params, points `adios_config` at the SST XML

See [`insitu_agent/README.md`](insitu_agent/README.md) for the full tool list
and agent transcript examples.

---

## 3  Offline Rendering (no streaming)

If you just have a BP5 file on disk, render it with `pvbatch`:

```bash
docker run --gpus all --rm -v $(pwd)/output:/output -v $(pwd)/data:/data \
  sci-paraview-deploy \
  pvbatch --force-offscreen-rendering -c "
    from paraview.simple import *
    reader = FidesReader(FileName='/data/gs.bp')
    reader.UpdatePipeline()
    display = Show(reader)
    display.SetRepresentationType('Volume')
    ColorBy(display, ('POINTS', 'U'))
    Render()
    SaveScreenshot('/output/gray_scott.png')
  "
```

Parallel variant:

```bash
mpirun -np 4 --allow-run-as-root pvbatch --force-offscreen-rendering render_script.py
```

---

## 4  Multi-Node Parallel Rendering

```bash
# On each worker
docker run --gpus all -d --rm --hostname worker1 --network host \
  --name pv-worker1 sci-paraview-deploy /usr/sbin/sshd -D

# From head node
mpirun -np 6 --allow-run-as-root \
  --host $(hostname):2,worker1:2,worker2:2 \
  pvbatch --force-offscreen-rendering render_script.py
```

ParaView partitions the data across ranks automatically.

---

## 5  Validation

```bash
# Single-node: pvbatch render + BP5 write/read + 2-rank MPI pvbatch
docker compose run --rm validate

# Multi-node: head + 2 workers, 3-rank pvbatch
docker compose up --abort-on-container-exit --exit-code-from head head

docker compose down
```

Expect `SINGLE-NODE TEST PASSED` / `CLUSTER TEST PASSED`.

---

## SST Tuning (in-transit)

Edit `insitu_agent/adios2-sst.xml`:

| Parameter | Effect |
|---|---|
| `QueueLimit` | Steps buffered in SST. Higher = more lag tolerance for slow readers. |
| `QueueFullPolicy` | `Discard` (sim never blocks, agent may skip steps) vs `Block` (sim waits). |
| `RendezvousReaderCount` | `1` = sim waits for reader to attach; `0` = sim starts immediately. |
| `DataTransport` | `WAN` (TCP, cross-node) or `MPI` (same-node, faster). |

---

## Enabled Features

| Feature | Details |
|---|---|
| Qt6 GUI | `paraview` client for interactive visualization |
| ADIOS2 2.10.2 | BP5 (default), BP4, SST, HDF5, Inline/Plugin engines |
| Fides | Schema-driven ADIOS2 reader for the VTK pipeline |
| MPI | Parallel rendering via `pvserver` / `pvbatch` |
| Catalyst 2.0 | In-situ analysis API (libcatalyst) + Catalyst Live |
| Python 3.12 | `pvpython`, `pvbatch`, `paraview.simple` scripting |
| MCP | Expose ParaView as tools for LLM agents (in-transit workflow) |

---

## Troubleshooting

**Segfault during Catalyst init** — Python version mismatch. Use 3.11/3.12, not
3.14. Rebuild ParaView with `^python@3.12`.

**`ModuleNotFoundError: No module named 'paraview'`** — `PYTHONPATH` missing
ParaView site-packages:

```bash
PARAVIEW_PREFIX=$(spack location -i paraview@5.13.3)
export PYTHONPATH="$PARAVIEW_PREFIX/lib/python3.12/site-packages:$PYTHONPATH"
```

**Verbose Catalyst logs:**

```bash
export CATALYST_DEBUG=1
export PARAVIEW_LOG_CATALYST_VERBOSITY=INFO
```

---

## References

- ParaView: https://docs.paraview.org
- ADIOS2 Gray-Scott tutorial: https://adios2.readthedocs.io/en/latest/tutorials/gray_scott.html
- Fides reader: https://fides.readthedocs.io
- Catalyst in-situ: https://catalyst-in-situ.readthedocs.io
- Model Context Protocol: https://modelcontextprotocol.io
