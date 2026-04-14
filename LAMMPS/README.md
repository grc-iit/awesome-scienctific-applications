# LAMMPS (Large-scale Atomic/Molecular Massively Parallel Simulator)

## Overview

LAMMPS is a classical molecular dynamics (MD) simulation code designed for parallel computing. Developed at Sandia National Laboratories, it can model atomic, polymeric, biological, metallic, granular, and coarse-grained systems using a variety of force fields and boundary conditions. LAMMPS is widely used in materials science, chemistry, physics, and engineering research.

## Key Features

- **Broad force field support**: Lennard-Jones, EAM, CHARMM, AMBER, OPLS, ReaxFF, AIREBO, Tersoff, and many more
- **Massively parallel**: Spatial decomposition with MPI; GPU and OpenMP acceleration
- **Extensible**: Plugin architecture with numerous optional packages
- **Flexible**: Supports 2D and 3D simulations, various ensembles (NVE, NVT, NPT, etc.)
- **Rich analysis**: On-the-fly computation of thermodynamic quantities, structural properties, and time correlations
- **Coupling support**: Interfaces with ADIOS2, Python, and other tools for in-situ analysis and multi-scale workflows

## Dependencies

- C++ compiler (C++11 or later)
- MPI library
- CMake (build system)
- Optional: FFTW3, ADIOS2, Python, CUDA/HIP (GPU acceleration), Kokkos

## Build Instructions

```bash
mkdir build && cd build
cmake ../cmake -DPKG_MANYBODY=on -DPKG_KSPACE=on
make -j
```

To enable ADIOS2 support:

```bash
cmake ../cmake -DPKG_ADIOS=on -DADIOS2_DIR=/path/to/adios2
```

## Usage

```bash
mpirun -n <num_procs> ./lmp -in input.lammps
```

## Input Script Example

```lammps
units           metal
atom_style      atomic
lattice         fcc 3.615
region          box block 0 10 0 10 0 10
create_box      1 box
create_atoms    1 box
mass            1 63.546

pair_style      eam
pair_coeff      * * Cu_u3.eam

velocity        all create 300.0 87287

fix             1 all npt temp 300 300 0.1 iso 0.0 0.0 1.0
timestep        0.001

thermo          100
dump            1 all atom 1000 dump.lammpstrj

run             10000
```

## References

- Thompson, A.P., Aktulga, H.M., Berger, R., et al. (2022). "LAMMPS - a flexible simulation tool for particle-based materials modeling at the atomic, meso, and continuum scales." *Computer Physics Communications*, 271, 108171.
- Plimpton, S. (1995). "Fast Parallel Algorithms for Short-Range Molecular Dynamics." *Journal of Computational Physics*, 117(1), 1-19.
- Official website: https://www.lammps.org
- Official repository: https://github.com/lammps/lammps
