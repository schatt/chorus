#!/usr/bin/env bash
bin=`readlink "$0"`
if [ "$bin" == "" ]; then
 bin=$0
fi
bin=`dirname "$bin"`
bin=`cd "$bin"; pwd`

. "$bin"/chorus-config.sh

MAX_WAIT_TIME=$1

if [ -f $INDEXER_PID_FILE ]; then
  if kill -2 `cat $INDEXER_PID_FILE` > /dev/null 2>&1; then
    log_inline "stopping indexer "
    kill `cat $INDEXER_PID_FILE`
    wait_for_stop_or_force $INDEXER_PID_FILE $MAX_WAIT_TIME
    rm -f $INDEXER_PID_FILE
  else
    log "could not stop indexer. check that process `cat $INDEXER_PID_FILE` exists"
    exit 0
  fi
else
  log "no indexer to stop"
fi
