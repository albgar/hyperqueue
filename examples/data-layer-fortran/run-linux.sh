#!/usr/bin/env bash
# Requires Linux, a Fortran compiler, and the v0.25.1 `hq` executable on PATH.
set -euo pipefail

command -v hq >/dev/null || { echo 'hq is not on PATH' >&2; exit 127; }
fortran_compiler="${FC:-gfortran}"
command -v "$fortran_compiler" >/dev/null || {
    echo "Fortran compiler not found: $fortran_compiler" >&2
    exit 127
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/hq-data-layer-fortran.XXXXXX")"
mkdir -p "$run_dir/bin" "$run_dir/server" "$run_dir/producer-work" "$run_dir/consumer-work"

# Build into the run directory: tasks will run with this directory as their cwd.
"$fortran_compiler" -std=f2008 -O2 "$script_dir/producer.f90" -o "$run_dir/bin/producer"
"$fortran_compiler" -std=f2008 -O2 "$script_dir/consumer.f90" -o "$run_dir/bin/consumer"

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

hq server start --host 127.0.0.1 --journal "$run_dir/journal" >"$run_dir/server.log" 2>&1 &
server_pid=$!
hq server wait

hq worker start --hostname localhost --resource 'producer=sum(1)' >"$run_dir/producer-worker.log" 2>&1 &
producer_worker_pid=$!
hq worker start --hostname localhost --resource 'consumer=sum(1)' >"$run_dir/consumer-worker.log" 2>&1 &
consumer_worker_pid=$!

if ! timeout 30s hq worker wait 2; then
    echo 'Two workers did not register within 30 seconds.' >&2
    cat "$run_dir/producer-worker.log" "$run_dir/consumer-worker.log" >&2 || true
    exit 1
fi

pushd "$run_dir" >/dev/null
hq job submit-file "$script_dir/job.toml"
hq job wait 1
popd >/dev/null

echo
echo 'Fortran data-layer POC succeeded:'
cat "$run_dir/producer.stdout"
cat "$run_dir/consumer.stdout"
echo
echo 'The source and downloaded files have independent names and task directories:'
ls -l "$run_dir/producer-work/producer-result.bin" "$run_dir/consumer-work/fft-input.bin"
cmp -s "$run_dir/producer-work/producer-result.bin" "$run_dir/consumer-work/fft-input.bin"
echo 'Their byte contents are identical.'
echo "Logs, binaries, and task files are in: $run_dir"
