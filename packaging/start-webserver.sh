#!/usr/bin/env bash
bin=`readlink "$0"`
if [ "$bin" == "" ]; then
 bin=$0
fi
bin=`dirname "$bin"`
bin=`cd "$bin"; pwd`

. "$bin"/chorus-config.sh

# start nginx and the application server
# in development, start mizuno in foreground
# in production, start jetty in background

STARTING="web server"
depends_on postgres

# If NGINX is already running
if ( test -f $NGINX_PID_FILE ) && ( kill -0 `cat $NGINX_PID_FILE` > /dev/null 2>&1 ); then
    log "nginx already running as process `cat $NGINX_PID_FILE`."
else
    log "Writing nginx config..."
    RAILS_ENV=$RAILS_ENV $RUBY vendor/nginx/generate_nginx_conf.rb
    cd $CHORUS_HOME/vendor/nginx/nginx_dist/

    OPENSSL_CONF=$OPENSSL_CONF ./$NGINX
    wait_for_start $NGINX_PID_FILE
    log "nginx started as pid `cat $NGINX_PID_FILE`"
fi

cd $CHORUS_HOME

case $RAILS_ENV in
    development )

        # If Mizuno is already running
        if ( test -f $MIZUNO_PID_FILE ) && ( kill -0 `cat $MIZUNO_PID_FILE` > /dev/null 2>&1 ); then
            log "Mizuno already running as process `cat $MIZUNO_PID_FILE`."
        else
            log "starting mizuno on port 3000..."
            #running mizuno in daemon mode (-D) is causing the command prompt to get screwed up
            if JRUBY_OPTS=$JRUBY_OPTS SOLR_PORT=$SOLR_PORT bundle exec mizuno -p 3000 --log $CHORUS_HOME/log/mizuno.log --threads 10 -D --pidfile $MIZUNO_PID_FILE; then
                wait_for_start $MIZUNO_PID_FILE
            fi
        fi
        ;;
    * )

        if ( test -f $JETTY_PID_FILE ) && ( kill -0 `cat $JETTY_PID_FILE` > /dev/null 2>&1 ); then
            log "jetty already running as process `cat $JETTY_PID_FILE`."
        else
            log "updating jetty config..."
            $RUBY packaging/update_jetty_xml.rb
            RAILS_ENV=$RAILS_ENV $RUBY packaging/update_database_yml.rb

            log "starting jetty..."
            cd $CHORUS_HOME/vendor/jetty/
            JETTY_PID=$JETTY_PID_FILE CHORUS_JAVA_OPTIONS=$CHORUS_JAVA_OPTIONS RAILS_ENV=$RAILS_ENV SOLR_PORT=$SOLR_PORT ./jetty-init start 2>> $CHORUS_HOME/log/jetty.log >> $CHORUS_HOME/log/jetty.log &
            cd $CHORUS_HOME
            wait_for_start $JETTY_PID_FILE
			log "jetty started as pid `cat $JETTY_PID_FILE`"
        fi
        ;;
esac
