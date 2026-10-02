#!/usr/bin/env bash
# Run this *inside* the v0.25.1 container image; see README.md.
set -euo pipefail

# The image keeps the binary at /hq; make it visible to task shells too.
export PATH="/:${PATH}"

run_dir="${1:-/work/.data-layer-poc-run}"
if [[ -e "$run_dir" ]]; then
    echo "Refusing to reuse existing directory: $run_dir" >&2
    exit 2
fi
mkdir -p "$run_dir/server"
export HQ_SERVER_DIR="$run_dir/server"

server_pid=''
producer_worker_pid=''
consumer_worker_pid=''
cleanup() {
    for pid in "$consumer_worker_pid" "$producer_worker_pid" "$server_pid"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

/hq server start --host 127.0.0.1 --journal "$run_dir/journal" >"$run_dir/server.log" 2>&1 &
server_pid=$!
/hq server wait

/hq worker start --hostname localhost --resource 'producer=sum(1)' >"$run_dir/producer-worker.log" 2>&1 &
producer_worker_pid=$!
/hq worker start --hostname localhost --resource 'consumer=sum(1)' >"$run_dir/consumer-worker.log" 2>&1 &
consumer_worker_pid=$!

if ! timeout 30s /hq worker wait 2; then
    echo 'Two workers did not register within 30 seconds.' >&2
    cat "$run_dir/producer-worker.log" "$run_dir/consumer-worker.log" >&2 || true
    exit 1
fi

# The graph contains a data dependency, so the consumer cannot be scheduled
# until the producer publishes output ID 7.
/hq job submit-file /work/examples/data-layer-poc/job.toml
/hq job wait 1

echo
echo 'Data-layer POC succeeded (the consumer ran on the other worker):'
cat /work/consumer.stdout
echo "Artifacts and logs: $run_dir"
