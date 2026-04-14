# Gray-Scott Reaction-Diffusion Simulation

## Overview

The Gray-Scott model is a mathematical model of a reaction-diffusion system that describes the interaction between two chemical species, U and V. The model produces a rich variety of spatiotemporal patterns, including spots, stripes, waves, and complex self-replicating structures, depending on the feed rate (F) and kill rate (k) parameters.

## Governing Equations

The Gray-Scott model is described by the following partial differential equations:

```
dU/dt = Du * nabla^2(U) - U * V^2 + F * (1 - U)
dV/dt = Dv * nabla^2(V) + U * V^2 - (F + k) * V
```

Where:
- **U, V** — Concentrations of the two chemical species
- **Du, Dv** — Diffusion rates of U and V
- **F** — Feed rate (rate at which U is replenished)
- **k** — Kill rate (rate at which V is removed)
- **nabla^2** — Laplacian operator (diffusion)

## Features

- 2D and 3D reaction-diffusion simulation
- Configurable feed rate (F) and kill rate (k) parameters
- Support for parallel execution using ADIOS2 for I/O
- Multiple output formats for visualization and analysis

## Dependencies

- C/C++ compiler
- MPI (Message Passing Interface)
- ADIOS2 (for parallel I/O and data staging)
- CMake (build system)

## Build Instructions

```bash
mkdir build && cd build
cmake ..
make
```

## Usage

```bash
mpirun -n <num_procs> ./gray-scott settings.json
```

## Configuration

Simulation parameters are typically defined in a JSON settings file:

```json
{
    "L": 128,
    "Du": 0.2,
    "Dv": 0.1,
    "F": 0.02,
    "k": 0.048,
    "dt": 1.0,
    "steps": 10000,
    "plotgap": 100
}
```

## References

- Pearson, J.E. (1993). "Complex Patterns in a Simple System." *Science*, 261(5118), 189-192.
- Gray, P. and Scott, S.K. (1985). "Sustained oscillations and other exotic patterns of behavior in isothermal reactions." *The Journal of Physical Chemistry*, 89(1), 22-32.
- ADIOS2 Gray-Scott Example: https://github.com/ornladios/ADIOS2/tree/master/examples/simulations/gray-scott
