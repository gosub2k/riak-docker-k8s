#!/bin/bash
set -e

RIAK_NODENAME=${RIAK_NODENAME:-127.0.0.1}

# Set ulimits required by Riak
ulimit -n 262144 2>/dev/null || echo "Warning: Could not set open files limit (run container with --ulimit nofile=262144:262144)"
ulimit -u 65536 2>/dev/null || echo "Warning: Could not set max user processes"

if [ -d "/opt/riak/bin" ]; then
    RIAK_DIR="/opt/riak"
else
    echo "ERROR: Cannot find Riak installation"
    exit 1
fi

RIAK_CONF="$RIAK_DIR/etc/riak.conf"
LOG_DIR="$RIAK_DIR/log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Configure Riak to listen on all interfaces
sed -i 's/^listener.http.internal = 127.0.0.1:/listener.http.internal = 0.0.0.0:/' "$RIAK_CONF"
sed -i 's/^listener.protobuf.internal = 127.0.0.1:/listener.protobuf.internal = 0.0.0.0:/' "$RIAK_CONF"

# Use 127.0.0.1 for nodename so Erlang doesn't reject container hostnames
sed -i "s/^nodename = .*/nodename = riak@$RIAK_NODENAME/" "$RIAK_CONF"

# Export PATH to include Riak binaries
export PATH="$RIAK_DIR/bin:$PATH"

echo "Starting: riak $@"
exec riak $@
