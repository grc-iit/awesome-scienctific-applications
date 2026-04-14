# Xcompact3d

## Overview

Xcompact3d is a powerful high-order flow solver for academic research. It is dedicated to the study of turbulent flows on supercomputers using direct numerical simulation (DNS) and large-eddy simulation (LES). The code is based on sixth-order compact finite difference schemes on a Cartesian mesh for the spatial discretization and a third-order Adams-Bashforth scheme for the time integration.

## Key Features

- **High-order accuracy**: Sixth-order compact finite difference schemes for spatial discretization
- **Scalable**: Designed for massively parallel computing using a 2D domain decomposition strategy (2DECOMP&FFT library)
- **Versatile**: Supports DNS, LES, and RANS turbulence modeling
- **Immersed Boundary Method (IBM)**: Handles complex geometries on Cartesian meshes
- **Multiple flow configurations**: Channel flow, turbulent boundary layer, cylinder flow, mixing layer, jet flow, and more

## Governing Equations

Xcompact3d solves the incompressible (or low-Mach number) Navier-Stokes equations:

```
du/dt + (u . nabla)u = -nabla(p) + nu * nabla^2(u) + f
nabla . u = 0
```

## Dependencies

- Fortran compiler (gfortran, ifort, or similar)
- MPI library
- FFTW3 or equivalent FFT library
- ADIOS2 (optional, for parallel I/O)
- CMake (build system)

## Build Instructions

```bash
mkdir build && cd build
cmake .. -DCMAKE_Fortran_COMPILER=mpif90
make -j
```

## Usage

```bash
mpirun -n <num_procs> ./xcompact3d input.i3d
```

## Configuration

Simulations are configured through an `.i3d` input file specifying:
- Domain size and mesh resolution
- Boundary conditions
- Time stepping parameters
- Turbulence model selection
- Output frequency and format

## References

- Bartholomew, P., Deskos, G., Frantz, R.A.S., Schuch, F.N., Lamballais, E. and Laizet, S. (2020). "Xcompact3D: An open-source framework for solving turbulence problems on a Cartesian mesh." *SoftwareX*, 12, 100550.
- Laizet, S. and Lamballais, E. (2009). "High-order compact schemes for incompressible flows: A simple and efficient method with quasi-spectral accuracy." *Journal of Computational Physics*, 228(16), 5989-6015.
- Official repository: https://github.com/xcompact3d/Incompact3d
