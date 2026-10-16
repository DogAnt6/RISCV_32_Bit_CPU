## Project Overview

Designed and implemented a 32-bit single-cycle RISC-V CPU in SystemVerilog, targeting the Sipeed Tang Nano 20K FPGA. The processor implements a subset of the RV32I instruction set and features a modular datapath, register file, ALU, control unit, instruction memory, data memory, and memory-mapped I/O.

The CPU executes each instruction in a single clock cycle, with functional verification performed in Questa and hardware implementation using Gowin FPGA Designer.

<img width="1082" height="673" alt="image" src="https://github.com/user-attachments/assets/2727fba2-f4c0-4ee8-95c5-d4144d1f60a9" />

### Instruction Execution

Each instruction completes the following operations within one clock cycle:

1. **Instruction Fetch:** Retrieve the instruction from instruction memory using the PC.
2. **Decode:** Identify the instruction type, source registers, and control signals.
3. **Execute:** Perform the ALU operation or calculate the memory address.
4. **Memory Access:** Read or write data memory when required.
5. **Write-Back:** Update the destination register with the ALU or memory result.

The program counter is updated at the clock edge, either advancing to the next instruction or branching to a calculated target address.

## Supported Instructions

The processor implements the following subset of the RISC-V RV32I instruction set:

| Type | Instructions |
|---|---|
| R-Type | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT` |
| I-Type | `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI` |
| Load | `LW` |
| Store | `SW` |
| Branch | `BEQ` |

## Performance & Timing

The 32-bit single-cycle RISC-V CPU was synthesized and implemented on the **Sipeed Tang Nano 20K FPGA (GW2AR-18)** using Gowin FPGA Designer.

Each instruction executes in a single clock cycle, resulting in a CPI (Cycles Per Instruction) of 1.

| Metric | Result |
|---|---|
| Architecture | 32-bit RISC-V (Single-Cycle) |
| FPGA | Sipeed Tang Nano 20K (GW2AR-18) |
| Operating Clock Frequency | 27 MHz |
| Maximum Frequency (Post-Place-and-Route Fmax) | 33.468 MHz |

### Timing Analysis

- **Operating Frequency:** 27 MHz, using the FPGA's onboard oscillator.
- **Maximum Achievable Frequency:** 33.468 MHz, estimated through post-place-and-route static timing analysis.
- **Critical Path:** Approximately 29.88 ns, based on the reported Fmax.

The CPU also supports memory-mapped I/O (MMIO), allowing software instructions to control the FPGA's onboard LEDs through store operations.
