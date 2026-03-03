#!/bin/bash
set -e

RIAK_CONF=/opt/riak/etc/riak.conf
RIAK_SUBDOMAIN=riak-headless

# Data from configMap goes into config file...
echo "$RIAK_CONF_INITIAL_DATA" > $RIAK_CONF

# Custom riak host name
RIAK_ID="${POD_NAME}.${RIAK_SUBDOMAIN}"
sed -i.k8sbak -e "s/riak@127.0.0.1/riak@${RIAK_ID}/" $RIAK_CONF

# Start riak
riak daemon
while ! riak ping; do
  echo "Waiting for riak to come up..."
  sleep 10
done
echo "riak is up!"

# Check if this node is in 'leaving' state from a previous crash/restart.
# If so, force-remove it and re-join cleanly.
member_status=$(riak-admin member-status 2>/dev/null | grep "riak@${RIAK_ID}" | awk '{print $2}') || true
if [ "$member_status" = "leaving" ]; then
  echo "Node is in 'leaving' state — clearing stale cluster membership..."
  riak-admin cluster force-remove "riak@${RIAK_ID}" || true
  riak-admin cluster plan || true
  riak-admin cluster commit || true
  # Restart riak so it comes up with a clean ring
  riak stop
  sleep 5
  riak daemon
  while ! riak ping; do
    echo "Waiting for riak to come back up after force-remove..."
    sleep 10
  done
  echo "riak restarted with clean state"
fi

join_cluster() {
  local base_host=${POD_NAME%%-*}  # extract stateful set name
  for i in $(seq 0 0); do  # 
    if [ "$base_host-$i" = "$POD_NAME" ]; then
      continue
    fi
    local try_host=$base_host-$i.${RIAK_SUBDOMAIN}
    echo "Trying to join cluster: $try_host"
    if ! grep error <(riak-admin cluster join "riak@$try_host"); then
      echo "Joined cluster"
      if riak-admin cluster plan && riak-admin cluster commit; then
        echo "Committed to cluster"
        return 0
      fi
    else
      echo "Failed to join cluster at $try_host"
    fi
    sleep 10
  done
  return 1
}

# Try to join cluster
if join_cluster; then
  echo "Successfully joined and committed to cluster"
else
  echo "This host did not join the cluster at startup"
fi

# Keep alive and periodically log cluster status
while true; do
  echo -n "sleeping..."
  sleep 30
  echo "$(date): cluster status:"
  riak-admin cluster status
done
