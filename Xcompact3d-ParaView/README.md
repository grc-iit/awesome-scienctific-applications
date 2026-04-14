# Xcompact3d ParaView Visualization

## Overview

This application provides ParaView-based visualization and post-processing for Xcompact3d turbulent flow simulations. It enables rendering of velocity fields, vortical structures, turbulence statistics, and other flow quantities produced by Xcompact3d. Using ADIOS2 for I/O, data can be visualized either in-situ during a running simulation or post-hoc from output files.

## Key Features

- **Flow field visualization**: Render velocity, pressure, and scalar fields from Xcompact3d output
- **Vortex identification**: Q-criterion, lambda2-criterion, and vorticity magnitude for vortical structure visualization
- **Turbulence statistics**: Mean velocity profiles, Reynolds stresses, energy spectra
- **In-situ analysis**: Real-time visualization of ongoing simulations via ADIOS2 SST engine
- **Slice and probe**: Extract 2D slices, line probes, and point data from 3D fields
- **Parallel rendering**: Distributed visualization of large-scale DNS/LES data

## Architecture

```
Xcompact3d Simulation  --(ADIOS2 SST/BP)-->  ParaView VTK Pipeline  -->  Rendered Output
```

## Dependencies

- ParaView (5.10+)
- VTK
- ADIOS2 (with Python bindings)
- Python 3 (NumPy, ParaView Python modules)
- MPI library
- CMake (build system)

## Build Instructions

```bash
mkdir build && cd build
cmake .. -DParaView_DIR=/path/to/paraview -DADIOS2_DIR=/path/to/adios2
make -j
```

## Usage

### Post-hoc Visualization

```python
from paraview.simple import *

# Load Xcompact3d output
reader = ADIOSReader(FileName='output.bp')

# Compute Q-criterion for vortex visualization
calc = Calculator(Input=reader)
calc.Function = '0.5*(Vorticity_mag^2 - StrainRate_mag^2)'
calc.ResultArrayName = 'Q_criterion'

# Render isosurface of Q-criterion
contour = Contour(Input=calc)
contour.ContourBy = 'Q_criterion'
contour.Isosurfaces = [0.5]

Show(contour)
ColorBy(GetDisplayProperties(contour), ('POINTS', 'Velocity', 'Magnitude'))
Render()
```

### In-situ Visualization

```bash
# Terminal 1: Run Xcompact3d with ADIOS2 SST output
mpirun -n 64 ./xcompact3d input.i3d

# Terminal 2: Run ParaView Catalyst or custom VTK reader
pvbatch visualization_script.py
```

### Common Visualizations

- **Instantaneous velocity field**: Volume rendering or vector glyphs
- **Vortical structures**: Isosurfaces of Q-criterion colored by velocity magnitude
- **Mean flow profiles**: Line plots of time-averaged velocity components
- **Energy spectra**: 1D power spectral density of velocity fluctuations
- **Reynolds stresses**: Contour plots of turbulent stress tensor components

## Configuration

ADIOS2 configuration for Xcompact3d data transport:

```xml
<adios-config>
  <io name="FlowOutput">
    <engine type="BP4"/>
    <transport type="File"/>
  </io>
</adios-config>
```

## References

- Bartholomew, P., et al. (2020). "Xcompact3D: An open-source framework for solving turbulence problems on a Cartesian mesh." *SoftwareX*, 12, 100550.
- Ayachit, U. (2015). *The ParaView Guide*. Kitware Inc.
- ParaView: https://www.paraview.org
- Xcompact3d: https://github.com/xcompact3d/Incompact3d
