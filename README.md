# VHDL Simulation using hdlmake and NVC

This is an example VHDL project that demonstrates how to simulate VHDL code using [hdlmake](https://github.com/hdl/hdlmake) and [NVC (Nick’s VHDL Compiler)](https://github.com/nickg/nvc). The goal is to automate simulation workflows using hdlmake for dependency management and Makefile generation, and NVC for compiling and running testbenches.

## Requirements

Make sure the following tools are installed on your system:

- [`hdlmake`](https://github.com/hdl/hdlmake)
- [`nvc`](https://github.com/nickg/nvc)
- `make` utility (typically pre-installed on Linux)

Install `hdlmake` via `pip`:

```bash
pip install hdlmake
```

Install NVC using your distribution's package manager or by building it from source (refer to the GitHub page).

## Project Structure

```
vhdl-project/
├── modules/
│   └── generic_core.vhd
├── testbench/
│   ├── Manifest.py
│   └── generic_testbench.vhd
```

- **modules/** contains the VHDL modules to be tested.
- **testbench/** contains the testbench file and the `Manifest.py` descriptor used by hdlmake.

## Simulation with *hdlmake* and NVC

Follow these steps to simulate the project using hdlmake and NVC.

### 1. Navigate to the testbench directory

In your terminal, go to the directory containing the `Manifest.py` file:

```bash
cd path/to/vhdl-project/testbench/
```

### 2. Generate build files with hdlmake

Run the following command to generate a Makefile and build structure:

```bash
hdlmake
```

This command will analyze the dependencies and create a `nvc/` folder with a custom Makefile for NVC.

### 3. Compile and run simulation using NVC

Switch to the generated `nvc/` folder and run:

```bash
cd nvc
make
```

The `make` command will invoke NVC to compile and run the testbench automatically.

### 4. Simulation Output

If the simulation runs correctly, you’ll see output similar to:

```bash
nvc --work=work --std=2008 -a   ../../../modules/generic_core.vhd
nvc --work=work --std=2008 -a   ../generic_testbench.vhd
nvc --std=2008 -e --no-collapse generic_testbench
nvc -r --dump-arrays --exit-severity=error generic_testbench --wave=generic_testbench.fst --format=fst
** Note: ********: Test 1 passed.
Process :generic_testbench:_p1 at ../generic_testbench.vhd:1xx
** Note: ********: Test 2 passed.
...
** Note: ********: FINISH called
```

A waveform file (`.fst`) will be generated if configured. You can visualize it using [GTKWave](http://gtkwave.sourceforge.net/) or [Surfer](https://surfer-project.org/).

## Notes

- Make sure `Manifest.py` correctly defines the top-level testbench and source file paths.
- This project uses the VHDL-2008 standard (`--std=2008`).

