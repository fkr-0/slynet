#!/usr/bin/env bash

# simple runner for server

# args:
# status - pgrep -lfa | slynet-cli
# killall - pgrep -lfa | slynet-cli | awk '{print $1}'
# start-sync janet slynet/slynet-cli.janet
# start janet slynet/slynet-cli.janet &

case $1 in
status)
  pgrep -lfa slynet-cli
  ;;
killall)
  pgrep -lfa slynet-cli | awk '{print $1}' | xargs kill -9
  ;;
start-sync)
  shift
  janet "slynet/slynet-cli.janet"
  ;;
client)
  shift
  janet "slynet-client.janet"
  ;;
start)
  shift
  janet "slynet/slynet-cli.janet" &
  ;;
*)
  echo "Usage: $0 {status|killall|start-sync|start|client} [args...]"
  exit 1
  ;;
esac

exit 0
