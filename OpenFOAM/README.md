# OpenFOAM (Open Source Field Operation and Manipulation)

## Overview

OpenFOAM is a free, open-source computational fluid dynamics (CFD) toolbox. It provides an extensive range of solvers for problems in fluid flow, heat transfer, combustion, turbulence, multiphase flow, solid mechanics, electromagnetics, and acoustics. OpenFOAM uses the finite volume method (FVM) on unstructured meshes and is widely adopted in both academic research and industrial applications.

## Key Features

- **Comprehensive solver library**: Incompressible/compressible flow, multiphase, heat transfer, combustion, particle tracking, electromagnetics
- **Turbulence modeling**: RANS (k-epsilon, k-omega SST, Spalart-Allmaras), LES (Smagorinsky, WALE, dynamic models), DES/DDES
- **Mesh flexibility**: Unstructured polyhedral meshes, mesh generation (blockMesh, snappyHexMesh), mesh manipulation tools
- **Parallel computing**: Domain decomposition with MPI; supports large-scale HPC simulations
- **Extensible**: Object-oriented C++ framework for developing custom solvers, boundary conditions, and models
- **Pre/post-processing**: Built-in function objects, ParaView integration, and data conversion utilities

## Governing Equations

OpenFOAM solves the Navier-Stokes equations in their general form using the finite volume method:

```
d(rho)/dt + nabla . (rho * U) = 0                          (Continuity)
d(rho * U)/dt + nabla . (rho * U * U) = -nabla(p) + nabla . tau + rho * g   (Momentum)
d(rho * E)/dt + nabla . (rho * U * E) = nabla . (k * nabla(T)) + ...        (Energy)
```

## Dependencies

- C++ compiler (GCC 7+, Clang, or Intel)
- MPI library (OpenMPI or MPICH)
- CMake / wmake (OpenFOAM build system)
- ParaView (for visualization)
- Scotch/METIS (domain decomposition)
- Optional: ADIOS2, CGAL, FFTW

## Installation

### From Source (OpenFOAM.org version)

```bash
# Clone the repository
git clone https://github.com/OpenFOAM/OpenFOAM-11.git
cd OpenFOAM-11

# Source the environment
source etc/bashrc

# Compile
./Allwmake -j
```

### From Source (OpenFOAM.com / ESI version)

```bash
git clone https://develop.openfoam.com/Development/openfoam.git
cd openfoam
source etc/bashrc
foamSystemCheck
./Allwmake -j
```

## Typical Workflow

1. **Pre-processing**: Define geometry, generate mesh, set boundary/initial conditions
2. **Solving**: Run the appropriate solver
3. **Post-processing**: Visualize and analyze results

```bash
# Generate mesh
blockMesh

# Decompose for parallel execution
decomposePar

# Run solver in parallel
mpirun -n <num_procs> simpleFoam -parallel

# Reconstruct results
reconstructPar

# Visualize
paraFoam
```

## Directory Structure

A typical OpenFOAM case directory:

```
case/
├── 0/              # Initial and boundary conditions
│   ├── U           # Velocity field
│   ├── p           # Pressure field
│   └── ...
├── constant/       # Physical properties and mesh
│   ├── transportProperties
│   ├── turbulenceProperties
│   └── polyMesh/   # Mesh definition
├── system/         # Simulation control
│   ├── controlDict
│   ├── fvSchemes
│   └── fvSolution
└── ...
```

## Common Solvers

| Solver | Description |
|---|---|
| `simpleFoam` | Steady-state incompressible turbulent flow (SIMPLE algorithm) |
| `pisoFoam` | Transient incompressible turbulent flow (PISO algorithm) |
| `pimpleFoam` | Transient incompressible flow (merged PISO-SIMPLE) |
| `interFoam` | Two-phase incompressible flow (VOF method) |
| `buoyantSimpleFoam` | Steady-state buoyant turbulent flow with heat transfer |
| `reactingFoam` | Combustion with chemical reactions |
| `sonicFoam` | Transient compressible turbulent flow |

## References

- Jasak, H. (1996). "Error Analysis and Estimation for the Finite Volume Method with Applications to Fluid Flows." PhD Thesis, Imperial College London.
- Weller, H.G., Tabor, G., Jasak, H., and Fureby, C. (1998). "A tensorial approach to computational continuum mechanics using object-oriented techniques." *Computers in Physics*, 12(6), 620-631.
- OpenFOAM Foundation: https://openfoam.org
- OpenFOAM ESI (OpenCFD): https://www.openfoam.com
- Official repository: https://github.com/OpenFOAM
