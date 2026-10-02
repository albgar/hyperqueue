# HyperQueue v0.25.1 data-layer tutorial

> This describes the experimental data layer in HyperQueue **v0.25.1**. It was
> removed in later releases. It is useful for experiments, but is neither a
> durable data store nor a supported feature in current HQ.

The data layer moves a task's file bytes to another task without requiring a
shared filesystem between their workers. It is a worker-memory mechanism for
workflow edges: a producer publishes data objects, then a downstream consumer
declares and retrieves them.

## Requirements

HQ v0.25.1 runs on Linux. Put its `hq` executable on `PATH` on the server and
workers. The commands `hq data put` and `hq data get` must be executed **inside
an HQ task**. A task receives `HQ_ACCESS_KEY`, which lets these commands connect
to the task-local worker data service; a normal shell does not have that access.

Enable the feature in a TOML job definition:

```toml
data_layer = true
```

## How one data edge works

For a producer task with ID 1 and a consumer task with ID 2:

```text
producer program writes a file
        |  hq data put <output-id> <source-file>
        v
producer worker RAM -- network when workers differ --> consumer worker RAM
                                                        |
                                                        | hq data get <input-index> <destination-file>
                                                        v
                                               consumer program reads a file
```

The server coordinates placements and dependencies, but stores metadata, not
the payload bytes.

Three pieces define the edge:

1. The producer publishes a regular file under a logical output ID:

   ```bash
   hq data put 3 producer-result.bin
   ```

2. The consumer declares that it needs task 1's output 3:

   ```toml
   [[task.data_deps]]
   task_id = 1
   output_id = 3
   ```

3. The consumer retrieves the first declared input:

   ```bash
   hq data get 0 fft-input.bin
   ```

`task_id` is a job-local task ID, not a worker ID. `output_id` is a logical
data-object key, not a filename. The data-dependency block belongs to the task
under whose `[[task]]` declaration it appears.

The `data_deps` declaration creates the scheduling/data contract: the consumer
waits until the producer has finished and published the named output, and HQ
arranges for the object to be present on the consumer worker. It does not itself
contain the bytes.

## Filenames are independent

HQ transfers object bytes, rather than a filesystem object with a name. The
producer and consumer may choose different filenames:

```text
producer: hq data put 3 producer-result.bin
consumer: hq data get 0 fft-input.bin
```

The link is `task_id = 1` plus `output_id = 3`. This is why independent workflow
components do not need an agreed basename. The source and destination files are
only adapters between file-oriented programs and the worker-memory data store.

## Multiple objects

Each object needs its own `[[task.data_deps]]` entry, even if both come from the
same producer:

```toml
[[task.data_deps]]
task_id = 1
output_id = 3

[[task.data_deps]]
task_id = 1
output_id = 4
```

The declaration order determines the zero-based input index:

```bash
hq data get 0 array-input.bin   # task 1, output 3
hq data get 1 factor-input.bin  # task 1, output 4
```

This verbosity lets HQ independently track object lifetime, placement, and
which downstream tasks need which object. If values always travel together,
package them in one file and use one `put`, one dependency block, and one `get`.

## Runtime behavior

1. The producer program writes an ordinary local file.
2. `hq data put` reads it into the producer worker's in-memory data store and
   records an output ID for the running task.
3. The server records the producer worker's placement, size, and consumers.
4. A consumer is scheduled after its inputs are available. If it is on a
   different worker, HQ downloads the object from a worker that holds it.
5. `hq data get` writes the consumer worker's in-memory bytes into the chosen
   destination file.

If producer and consumer share a worker, there is no network transfer. The
examples force different workers with distinct custom resource labels so the
inter-worker transfer is exercised.

The producer task may finish after `put`. The worker must remain alive while it
is the only copy holder. If that worker dies before a downstream worker obtains
the object, the object is lost and downstream consumers can fail. A worker that
has already downloaded the object can be another known placement. After `get`,
the consumer has an ordinary local file that does not depend on the data layer.

HQ removes its in-memory objects after their declared consumers no longer need
them. Do not regard it as an archive, checkpoint store, or durable queue.

## Formats and size

The layer sees opaque bytes. Any regular binary file can be transferred: raw
Fortran stream data, netCDF, HDF5, archives, or other binary formats. HQ does
not parse or validate its contents. `--mime-type` may accompany `put`, but it
does not change retrieval behavior.

For raw Fortran files, the applications must agree on element type, precision,
dimensions, array order, endianness, and header layout. A self-describing format
such as netCDF or HDF5 is often preferable for cross-platform workflows.

There is no configured practical per-object size limit in v0.25.1. The limit is
worker RAM and address space. Transfers use 128 KiB chunks, but the full object
is assembled and held in memory; this is not streaming. Budget for one complete
copy on the producer worker, one on every consumer worker that downloads it,
temporary copying overhead, and other live objects. Large objects or wide
fan-out can exhaust memory.

Although the CLI help mentions directories, this version's implementation opens
a regular file. Use regular files for `put`.

## Python and alternate transports

The public Python API in v0.25.1 has no `data_layer`, `data_deps`, `put`, or
`get` surface. A Python task could shell out to `hq data`, but Python cannot use
its public job-submission API to construct this data graph. CLI/TOML is the
practical interface.

ZeroMQ can implement a separate direct messaging system, but does not integrate
automatically with HQ's scheduling/dependency model. It requires endpoint
discovery, startup ordering, retry/failure handling, back-pressure, and
cleanup. Sentinel files require a shared filesystem and their own careful
failure handling. Use persistent storage or a purpose-built system when
durability, recovery, live streaming, or large fan-out is required.

## Included examples

### Shell POC

[`examples/data-layer-poc`](examples/data-layer-poc/README.md) transfers a text
file from a producer to a consumer on two workers.

```bash
./examples/data-layer-poc/run-linux.sh
```

### One Fortran object

[`examples/data-layer-fortran`](examples/data-layer-fortran/README.md) produces
ten random `integer(int32)` values in `producer-result.bin`; the consumer gets
the same bytes under the independent name `fft-input.bin`, then prints the mean.

```bash
FC=/usr/bin/gfortran ./examples/data-layer-fortran/run-linux.sh
```

### Two Fortran objects

[`examples/data-layer-fortran-two-streams`](examples/data-layer-fortran-two-streams/README.md)
has the producer publish an array on output ID 3 and a random real factor on
output ID 4. The consumer retrieves input indices 0 and 1, then publishes its
computed mean on output ID 5 and a scaled array on output ID 6.

```bash
FC=/usr/bin/gfortran ./examples/data-layer-fortran-two-streams/run-linux.sh
```

There is no third task in this compact example, so output IDs 5 and 6 are
published but have no later consumer. Add a third task with two `data_deps`
blocks to use those outputs.

`FC=/usr/bin/gfortran` is useful on a Linux host where Linuxbrew GCC is paired
with an old system linker. Omit it when the default compiler toolchain is
consistent.

## When it is a good fit

The old data layer is a reasonable experiment for bounded, transient,
file-shaped intermediate results where workers have ample RAM and worker loss
is acceptable or mitigated elsewhere. Prefer a shared filesystem, object store,
database, MPI, or another purpose-built mechanism for data that must survive
worker loss or be supported by newer HQ releases.
