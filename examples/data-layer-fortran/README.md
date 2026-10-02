# Fortran data-layer POC (HyperQueue v0.25.1)

This example transfers a raw binary array of ten `integer(int32)` values
between two simple Fortran programs. The producer runs in `producer-work` and
writes `producer-result.bin`. Its task uploads that file with `hq data put`.
The consumer runs separately in `consumer-work`; `hq data get` materializes the
same bytes as `fft-input.bin` there before the consumer reads it and prints its
mean. This demonstrates that the dependency uses output/input IDs, not a shared
filename.

The runner deliberately assigns the tasks to separate workers, so the bytes
cross the worker-to-worker data connection rather than only the local worker
data store.

## Requirements

- Linux
- `gfortran` on `PATH` (or another Fortran compiler supplied as `FC`)
- HyperQueue **v0.25.1** `hq` on `PATH`

## Run

From this repository's root:

```bash
./examples/data-layer-fortran/run-linux.sh
```

For example, to use the system compiler instead of a `gfortran` found first on
`PATH`:

```bash
FC=/usr/bin/gfortran ./examples/data-layer-fortran/run-linux.sh
```

The script compiles both programs into a fresh temporary directory, starts a
server and two workers, and prints both programs' output. It leaves logs,
executables, both binary files, and task stdout/stderr in the reported
directory. It lists the two distinct file paths and confirms that their byte
contents are identical. Task stdout/stderr is kept at the top of that temporary
directory, while each binary file remains in its own working directory.

The binary layout is intentionally simple: exactly ten native-endian 32-bit
integers. A real workflow should define and document its file format (for
example with a header, netCDF, or HDF5) when consumers may be built on a
different architecture or with a different data-layout expectation.
