# HyperQueue v0.25.1 data-layer POC

This is a deliberately small, command-line-only experiment for the experimental
data layer that existed in v0.25.1. It starts one server and two workers. A
producer task stores a file as output ID `7`; the consumer declares that output
as an input and retrieves input index `0`. Resource labels force the tasks onto
different workers, so this demonstrates an actual worker-to-worker transfer.

## Native Linux

Put the **v0.25.1** `hq` binary on `PATH`, then run:

```bash
./examples/data-layer-poc/run-linux.sh
```

It creates a temporary directory under `/tmp`, starts a server and two local
workers, waits for the job, prints the consumer's output, and leaves the logs
and task files in that temporary directory. It verifies that both workers
registered before submitting. Use `Ctrl-C` to stop it early.

## macOS via a Linux container

The image is built from this v0.25.1 checkout:

```bash
podman machine start              # macOS, if it is not already running
podman build -t hq-0.25.1-poc .
podman run --rm -it -v "$PWD":/work -w /work \
  --entrypoint /bin/bash hq-0.25.1-poc \
  /work/examples/data-layer-poc/run-in-container.sh
```

For Docker, replace `podman` with `docker` (and omit `podman machine start`).
The expected final line starts with `consumer received:` and includes
`transferred by HyperQueue data layer`.

`hq data put` and `hq data get` must run *inside an HQ task*. They use the
task's `HQ_ACCESS_KEY` to connect to the task-local data service, so they are
not commands for uploading/downloading files from the submitting shell.

The data is kept in workers' memory, is not a durable object store, and is
removed once its declared consumers no longer need it. The Python bindings in
this version do not expose `data_layer`, `data_deps`, `put`, or `get`; Python
can still launch a task that shells out to `hq data`, but it cannot submit this
data-dependency graph through its public API.
