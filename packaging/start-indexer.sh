#!/usr/bin/env bash
bin=`readlink "$0"`
if [ "$bin" == "" ]; then
 bin=$0
fi
bin=`dirname "$bin"`
bin=`cd "$bin"; pwd`

. "$bin"/chorus-config.sh

STARTING="indexer"
depends_on postgres solr

if [ -f $INDEXER_PID_FILE ]; then
  if kill -0 `cat $INDEXER_PID_FILE` > /dev/null 2>&1; then
    log "indexer already running as process `cat $INDEXER_PID_FILE`."
    exit 0
  fi
fi

RAILS_ENV=$RAILS_ENV $RUBY packaging/update_database_yml.rb
QUEUE="indexer_queue" JRUBY_OPTS=$JRUBY_OPTS CHORUS_JAVA_OPTIONS=$CHORUS_JAVA_OPTIONS_WITHOUT_XMS RAILS_ENV=$RAILS_ENV SOLR_PORT=$SOLR_PORT $RUBY script/rails runner "ChorusIndexer.new.start" >> $CHORUS_HOME/log/indexer.$RAILS_ENV.log 2>&1 &

indexer_pid=$!
echo $indexer_pid > $INDEXER_PID_FILE
log "indexer started as pid $indexer_pid"
