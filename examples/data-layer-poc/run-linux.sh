#!/usr/bin/env bash
# Requires the v0.25.1 `hq` executable to be on PATH.
set -euo pipefail

command -v hq >/dev/null || {
    echo 'hq is not on PATH' >&2
    exit 127
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/hq-data-layer-poc.XXXXXX")"
export HQ_SERVER_DIR="$run_dir/server"
mkdir "$HQ_SERVER_DIR"

server_pid=''
producer_worker_pid=''
consumer_worker_pid=''
cleanup() {
    for pid in "$consumer_worker_pid" "$producer_worker_pid" "$server_pid"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

hq server start --host 127.0.0.1 --journal "$run_dir/journal" >"$run_dir/server.log" 2>&1 &
server_pid=$!
hq server wait

hq worker start --hostname localhost --resource 'producer=sum(1)' >"$run_dir/producer-worker.log" 2>&1 &
producer_worker_pid=$!
hq worker start --hostname localhost --resource 'consumer=sum(1)' >"$run_dir/consumer-worker.log" 2>&1 &
consumer_worker_pid=$!

# Do not submit a job until both background worker processes have registered.
# Without this, `hq job wait` can appear to hang if a worker fails at startup.
if ! timeout 30s hq worker wait 2; then
    echo 'Two workers did not register within 30 seconds.' >&2
    echo "Producer worker log: $run_dir/producer-worker.log" >&2
    cat "$run_dir/producer-worker.log" >&2 || true
    echo "Consumer worker log: $run_dir/consumer-worker.log" >&2
    cat "$run_dir/consumer-worker.log" >&2 || true
    exit 1
fi

# Submit from the temporary directory so payloads and task output stay there.
pushd "$run_dir" >/dev/null
hq job submit-file "$script_dir/job.toml"
hq job wait 1
popd >/dev/null

echo
echo 'Data-layer POC succeeded:'
cat "$run_dir/consumer.stdout"
echo "Logs and task files are in: $run_dir"
