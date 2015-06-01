#!/usr/bin/env bash
bin=`readlink "$0"`
if [ "$bin" == "" ]; then
 bin=$0
fi
bin=`dirname "$bin"`
bin=`cd "$bin"; pwd`

. "$bin"/chorus-config.sh

ALPINE_PID_FILE="$ALPINE_HOME"/alpine.pid

if ( test -f $ALPINE_PID_FILE ) && ( kill -0 `cat $ALPINE_PID_FILE` > /dev/null 2>&1 ); then
    log "alpine already running as process `cat $ALPINE_PID_FILE`."
else
    if [ -f $ALPINE_HOME/alpine_control.sh ]; then
        log "starting alpine"
        CATALINA_PID=$ALPINE_PID_FILE $ALPINE_HOME/alpine_control.sh start >/dev/null
        wait_for_start $ALPINE_PID_FILE
		log "alpine started as pid `cat $ALPINE_PID_FILE`"
    fi
fi
