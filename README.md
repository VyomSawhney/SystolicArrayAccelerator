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

## Software-visible subsystem

`rtl/software_accelerator.sv` wraps the tiled GEMM engine with:

- Avalon-MM control and status registers
- Input and output on-chip matrix buffers
- DMA-style ready/valid streams for loading A/B and reading C
- Cycle and useful-MAC performance counters

The default demonstration configuration is `M=3`, `K=5`, `P=4`, and
`TILE_N=2`. Its register map uses word addresses:

| Address | Name | Read | Write |
| ---: | --- | --- | --- |
| `0x0` | CONTROL | — | bit 0 starts GEMM; bit 1 clears done |
| `0x1` | STATUS | busy, done, load-A, load-B, output-valid | — |
| `0x2` | DIMENSIONS | M, K, P, TILE_N | — |
| `0x3` | CYCLES | measured cycle count | — |
| `0x4` | MACS | useful MAC count | — |
| `0x5` | DMA_MODE | current mode | 1=load A, 2=load B, 3=read C |
| `0x6` | DMA_DATA_IN | — | write one input stream word |
| `0x7` | DMA_DATA_OUT_LO | read output bits 31:0 | — |
| `0x8` | DMA_DATA_OUT_HI | read output bits 34:32 | — |

Use the DMA input stream after selecting mode 1 or 2. Select mode 3 after
completion and consume `M*P` output values using ready/valid handshaking.
For a memory-mapped CPU, write input words to `0x6` and read output words
from `0x7` followed by `0x8`; these accesses are bridged internally to the
same stream protocol. The two reads refer to the same output word, and the
word advances only when `0x7` is read.

The RTL module is ready to attach to an Avalon-MM interconnect, but the
existing `de1_soc_accel.qsf` still builds the original pushbutton demo.
After integrating `software_accelerator` into a bus-connected top level, the
peripheral base address must be supplied to the Linux transport.

The standalone RTL regression is:

```bat
scripts\run_software_accelerator_sim.bat
```

The transport-independent Python reference model and driver are in
`python/software_accelerator.py`. The included test uses a fake register/DMA
transport to verify host-side flattening and FPGA-style result comparison:

```bat
python -m pytest python\test_software_accelerator.py -q
```

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