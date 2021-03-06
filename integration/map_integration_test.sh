#!/bin/bash
set -e
INTEGRATION_DIR="$( cd "$( dirname "$0" )" && pwd )"
. "${INTEGRATION_DIR}"/functions.sh

echo "Building code"
go build ${GOFLAGS} github.com/google/trillian/server/trillian_map_server/

yes | "${TRILLIAN_PATH}/scripts/resetdb.sh"

RPC_PORT=$(pick_unused_port)

echo "Starting Map RPC server on localhost:${RPC_PORT}"
./trillian_map_server --rpc_endpoint="localhost:${RPC_PORT}" http_endpoint='' &
RPC_SERVER_PID=$!
wait_for_server_startup ${RPC_PORT}
TO_KILL+=(${RPC_SERVER_PID})

echo "Running test"
cd "${INTEGRATION_DIR}"
set +e
go test ${GOFLAGS} --timeout=5m ./maptest  --map_rpc_server="localhost:${RPC_PORT}" 
RESULT=$?
set -e

echo "Stopping Map RPC server (pid ${RPC_SERVER_PID})"
kill_pid ${RPC_SERVER_PID}
TO_KILL=()

if [ $RESULT != 0 ]; then
    sleep 1
    echo "Server log:"
    echo "--------------------"
    cat "${TMPDIR}"/trillian_map_server.INFO
    exit $RESULT
fi
