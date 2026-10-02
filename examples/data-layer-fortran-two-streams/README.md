# Two-stream Fortran data-layer POC (HyperQueue v0.25.1)

This extends the one-stream Fortran example with two independent data objects.
The producer creates a random array of ten `integer(int32)` values and one
`real(real64)` factor between zero and one.

| Task | HQ output ID | Local source/destination file |
| --- | --- | --- |
| Producer | 3 | `producer-array.bin` |
| Producer | 4 | `producer-factor.bin` |
| Consumer | 5 | `consumer-mean.bin` |
| Consumer | 6 | `consumer-scaled-array.bin` |

The consumer's `data_deps` declares producer outputs 3 and 4. Thus its `hq data
get 0` fetches the array and `hq data get 1` fetches the factor. It computes the
mean and a factor-scaled array, then publishes those derived results on output
IDs 5 and 6. No third task consumes 5 and 6 in this compact POC; their
successful `put` calls demonstrate that a task can both consume and publish
multiple independent objects.

The tasks run on distinct workers and in distinct directories. The runner
confirms that each producer file has the same bytes as its consumer-side input,
despite their different names.

## Requirements and run

- Linux
- `gfortran` on `PATH`, or a compiler supplied using `FC`
- HyperQueue **v0.25.1** `hq` on `PATH`

```bash
./examples/data-layer-fortran-two-streams/run-linux.sh
```

If Homebrew GCC has a linker mismatch, use the system compiler, for example:

```bash
FC=/usr/bin/gfortran ./examples/data-layer-fortran-two-streams/run-linux.sh
```
