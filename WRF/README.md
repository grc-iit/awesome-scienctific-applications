# WRF (Weather Research and Forecasting Model)

## Overview

The Weather Research and Forecasting (WRF) model is a next-generation mesoscale numerical weather prediction system designed for both atmospheric research and operational forecasting. Developed collaboratively by NCAR, NOAA, and partner institutions, WRF is used worldwide for weather forecasting, regional climate simulations, air quality modeling, and coupled-model applications.

## Key Features

- **Multiple dynamical cores**: ARW (Advanced Research WRF) and NMM (Nonhydrostatic Mesoscale Model)
- **Comprehensive physics**: Multiple options for microphysics, cumulus parameterization, radiation, PBL, and land surface models
- **Nesting**: One-way and two-way grid nesting for multi-scale simulations
- **Data assimilation**: WRFDA system supporting 3DVAR, 4DVAR, and hybrid ensemble-variational methods
- **Scalable**: Designed for parallel computing with MPI and OpenMP
- **Coupled systems**: WRF-Chem (chemistry), WRF-Hydro (hydrology), WRF-Fire (wildfire)

## Governing Equations

WRF solves the fully compressible, nonhydrostatic Euler equations in flux form, using terrain-following hydrostatic-pressure vertical coordinates:

- Conservation of momentum (3D)
- Conservation of mass (continuity equation)
- Thermodynamic energy equation
- Conservation equations for moisture species
- Equation of state

## Dependencies

- Fortran and C compilers
- MPI library
- NetCDF (required for I/O)
- HDF5 (recommended)
- JasPer, libpng, zlib (for GRIB2 support in WPS)
- Optional: PnetCDF, ADIOS2

## Build Instructions

```bash
# Configure WRF
cd WRF
./configure    # Select compiler and parallelism options
./compile em_real -j 4

# Configure and compile WPS (WRF Preprocessing System)
cd ../WPS
./configure
./compile
```

## Typical Workflow

1. **WPS (Preprocessing)**: `geogrid.exe` -> `ungrib.exe` -> `metgrid.exe`
2. **Real**: `real.exe` (generate initial and boundary conditions)
3. **WRF**: `wrf.exe` (run the simulation)
4. **Post-processing**: NCL, Python, or other tools for visualization

```bash
mpirun -n <num_procs> ./real.exe
mpirun -n <num_procs> ./wrf.exe
```

## Configuration

WRF is configured through `namelist.input` for runtime parameters and `namelist.wps` for preprocessing:

- Domain setup (grid spacing, dimensions, nesting)
- Physics options (microphysics, radiation, PBL, cumulus, land surface)
- Dynamics options (time step, diffusion, damping)
- Output control (history interval, variables, file format)

## References

- Skamarock, W.C., Klemp, J.B., Dudhia, J., et al. (2019). "A Description of the Advanced Research WRF Model Version 4." *NCAR Technical Note*, NCAR/TN-556+STR.
- Powers, J.G., Klemp, J.B., Skamarock, W.C., et al. (2017). "The Weather Research and Forecasting Model: Overview, System Efforts, and Future Directions." *Bulletin of the American Meteorological Society*, 98(8), 1717-1737.
- Official website: https://www.mmm.ucar.edu/models/wrf
- Official repository: https://github.com/wrf-model/WRF
