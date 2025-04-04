# BIE-APS

Semestral project: implementation of single-cycle RISC-V processor ISA in Verilog.

Instructions implemented: add, addi, and, sub, srl, beq, blt, lw, sw, lui, jal, jalr.
Additionally implemented: floor_log - a custom routine, basically inline function of **prog1.asm**

## Contents
- **Artyushchenko_Artemii_CPU.v** - main file, logic is implemented here.
- **top.v** - top-level module.
- **Artyushchenko_Artemii_prog1.asm** - Assembly program for testing the processor: A routine that accepts 1 argument (a normalized positive single-precision floating-point number) and returns an integer value of the logarithm of that number rounded down
- **Artyushchenko_Artemii_prog1.hex** - **prog1.asm** dumped in hexadecimal format. 