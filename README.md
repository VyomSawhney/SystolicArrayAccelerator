# Systolic Array Accelerator

Parameterized SystemVerilog implementation of a signed, multiply-accumulate systolic array, with input skewing, output deskewing, and a controller. The default data width is 16 bits; the accumulator width scales with the array dimension to accommodate the reduction.

## Architecture

- `rtl/pe.sv` implements a processing element (PE): it stores a weight and, when enabled, multiplies the signed input by that weight and adds the incoming partial sum.
- `rtl/systolic_array.sv` connects the PEs into an `N` by `N` array.
- `rtl/input_skew_buffer.sv` and `rtl/output_deskew_buffer.sv` align input and output timing across the array.
- `rtl/controller.sv` sequences weight loading, computation, draining, and output deskewing.
- `rtl/accelerator.sv` connects these blocks and exposes the accelerator interface.

The RTL is parameterized by `N`, `DATA_W`, and `ACC_W`. `ACC_W` must be at least `2*DATA_W + $clog2(N)` at the accelerator level.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `rtl/` | Accelerator, PE, array, buffers, controller, and benchmark top-level RTL |
| `tb/` | Unit testbenches and parameter sweep testbench |
| `scripts/` | Windows batch scripts for simulation and Quartus builds |
| `constraints/` | Timing constraints for benchmark and DE1-SoC projects |
| `quartus/` | Quartus projects, benchmark results, and generated reports |
| `vivado/`, `sim/` | Vivado and simulation project files |
| `python/` | Python utilities |

## Tiled GEMM

`rtl/tiled_gemm.sv` provides a matrix-level interface for arbitrary `M x K`
by `K x P` signed matrix multiplication. It tiles the matrices into
`TILE_N x TILE_N` operations, zero-pads partial edge tiles, and exposes
cycle and useful-MAC counters. The existing `accelerator.sv` remains available
as the tile engine used by the Quartus benchmarks.

## Simulation

Run from a Windows command prompt or PowerShell with the Xilinx Vivado simulator commands `xvlog`, `xelab`, and `xsim` available on `PATH`:

```bat
scripts\run_accelerator_sim.bat
```

The script compiles the RTL and testbenches, elaborates `accelerator_sweep_tb`, and runs the sweep. The sweep instantiates accelerator testbenches for `N=2, 3, 4, 8, 16` with 16-bit data.
The same script also checks a non-square `3 x 5` by `5 x 4` GEMM for
`TILE_N=2`, `4`, and `8`.

The UVM environment runs 1,000 randomized transactions and is configurable
through the `ACCEL_N` environment variable:

```bat
scripts\run_accelerator_uvm_n2.bat
```

The default is `N=2`; for example, `set ACCEL_N=4` before running the same
script verifies the N=4 configuration. Its source is under `tb/uvm/`.

The directed corner-case UVM test can be run with:

```bat
scripts\run_accelerator_uvm_n2_corner.bat
```

The corner-case script uses the same `ACCEL_N` setting.

## Quartus Benchmarks

The benchmark projects target the Cyclone V `5CSEMA5F31C6` device and build `N=2`, `N=4`, and `N=8` configurations. The script compiles each project and runs Quartus timing analysis:

```bat
scripts\run_quartus_benchmarks.bat
```

The script currently expects Quartus Lite 25.1 at `C:\altera_lite\25.1std\quartus\bin64`. Update `QUARTUS_BIN` in the script if Quartus is installed elsewhere. Generated reports are placed in `quartus/output_files_n2`, `quartus/output_files_n4`, and `quartus/output_files_n8`.

## Quartus Results

Summary from [`quartus/accelerator_benchmark_results.csv`](quartus/accelerator_benchmark_results.csv):

| Device | N | PEs | ALMs | Registers | DSP blocks | M10K blocks | Post-fit Fmax (MHz) | Setup slack (ns) | Hold slack (ns) | Peak GMAC/s | Peak GOPS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 5CSEMA5F31C6 | 2 | 4 | 81 | 135 | 4 | 0 | 133.98 | 12.536 | 0.237 | 535.92 | 1,071.84 |
| 5CSEMA5F31C6 | 4 | 16 | 505 | 1,025 | 16 | 1 | 93.87 | 9.347 | 0.235 | 1,501.92 | 3,003.84 |
| 5CSEMA5F31C6 | 8 | 64 | 1,894 | 3,522 | 64 | 9 | 88.71 | 8.727 | 0.176 | 5,677.44 | 11,354.88 |

Peak throughput is calculated from the post-fit clock frequency assuming one multiply-accumulate per PE per cycle; GOPS counts a multiply and an addition as two operations. These are theoretical peak figures, not measured end-to-end workload throughput. Resource use and timing are Quartus implementation results; consult the per-configuration fit and STA reports for details.