# README

K8S configs for clustered Riak

## Design idea

The Riak config for K8S should handle
- pods crashing & restarting - Riak should not get stuck in "leaving" state
- Riak should join cluster on startup