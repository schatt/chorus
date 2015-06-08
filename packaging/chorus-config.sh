##### Required environment variables CHORUS_HOME and RAILS_ENV #####

if [ "$CHORUS_HOME" = "" ]; then
    echo CHORUS_HOME not set, it should be set to the Chorus installation directory
    exit 1
fi
# remove trailing '/' from CHORUS_HOME
CHORUS_HOME=`echo $CHORUS_HOME | sed 's/\/$//'`

ORIGINAL_CHORUS_HOME=$CHORUS_HOME
if [ -e $CHORUS_HOME/current ]; then
    CHORUS_HOME=$CHORUS_HOME/current
fi

if [ "$ALPINE_HOME" = "" ] && [ -e `dirname $CHORUS_HOME`/alpine-current ]; then
    export ALPINE_HOME=`dirname $CHORUS_HOME`/alpine-current
    export ALPINE_DATA_REPOSITORY=$ORIGINAL_CHORUS_HOME/shared/ALPINE_DATA_REPOSITORY
else
    export ALPINE_HOME=$ALPINE_HOME
    export ALPINE_DATA_REPOSITORY=$ALPINE_DATA_REPOSITORY
fi

if [ "$RAILS_ENV" = "" ]; then
    if [ -f $CHORUS_HOME/.development ]; then
        RAILS_ENV=development
    else
        RAILS_ENV=production
    fi
fi

case $RAILS_ENV in
    production )
        RUBY=$CHORUS_HOME/bin/ruby
        RAKE=$CHORUS_HOME/bin/rake
        ;;
    * )
        RUBY=jruby
        RAKE=rake
        ;;
esac

# Test for interactive shell
if [ -t 0 ]; then
    SHELL_CONFIG=`stty -g`
fi

PATH=$PATH:$CHORUS_HOME/packaging/dummy

##### PID file locations #####

mkdir -p $CHORUS_HOME/tmp/pids
SOLR_PID_FILE=$CHORUS_HOME/tmp/pids/solr-$RAILS_ENV.pid
NGINX_PID_FILE=$CHORUS_HOME/tmp/pids/nginx.pid
JETTY_PID_FILE=$CHORUS_HOME/tmp/pids/jetty.pid
SCHEDULER_PID_FILE=$CHORUS_HOME/tmp/pids/scheduler.$RAILS_ENV.pid
WORKER_PID_FILE=$CHORUS_HOME/tmp/pids/worker.$RAILS_ENV.pid
INDEXER_PID_FILE=$CHORUS_HOME/tmp/pids/indexer.$RAILS_ENV.pid
MIZUNO_PID_FILE=$CHORUS_HOME/tmp/pids/mizuno.pid

POSTGRES_DATA_DIR=$CHORUS_HOME/postgres-db
POSTGRES_PID_FILE=$POSTGRES_DATA_DIR/postmaster.pid

eval $($CHORUS_HOME/packaging/get_chorus_env_params)


##### Determine which nginx binary to use for this platform #####

unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
   NGINX=nginx_macos
else
   NGINX=nginx_linux
fi

##### nginx built with ssl support needs the environment variable OPENSSL_CONF #####
OPENSSL_CONF=$CHORUS_HOME/packaging/ssl/openssl.cnf

##### support functions #####

function log () {
    echo "[$RAILS_ENV] $1"
}

function log_inline () {
    echo -n "[$RAILS_ENV] $1"
}

function depends_on () {
    missing_dependencies=()
    dependency_num=1
    until [ -z "$1" ]  # Until all parameters used up . . .
    do
        pid_file=`echo $1 | tr '[:lower:]' '[:upper:]'`_PID_FILE
        if [ ! -f ${!pid_file} ]; then
            missing_dependencies[$dependency_num]=$1
            dependency_num=$(($dependency_num + 1))
        fi
        shift
    done

    if [ ${#missing_dependencies[@]} -ne 0 ]; then
        joiner=""
        message=""
        for missing_dependency in ${missing_dependencies[*]}
        do
            message=$message$joiner$missing_dependency
            joiner=", "
        done
        log "$message must be running to start the $STARTING"
        exit 1
    fi
}

function wait_for_start () {
    pid_file=$1
    until ( test -f $pid_file ) && ( kill -0 `head -1 $pid_file` > /dev/null 2>&1 )
    do
        sleep 1
    done
}

function wait_for_stop () {
    pid_file=$1
    while kill -0 `head -1 $pid_file 2>/dev/null` > /dev/null 2>&1
    do
        echo -n "."
        sleep 1
    done
    echo " ( Stopped )"
}

DEFAULT_WAIT_TIME=5
function wait_for_stop_or_force () {
    pid_file=$1

    MAX_WAIT_TIME=${2:-$DEFAULT_WAIT_TIME} # this awful notation means use parameter $2 if not null, else use value $DEFAULT_WAIT_TIME.
    time_waited=0
    while kill -0 `head -1 $pid_file 2>/dev/null` > /dev/null 2>&1
    do
        echo -n "."
        sleep 1

        # Negative values -> indefinite wait
        if [ "$MAX_WAIT_TIME" -lt "0" ]; then
            continue
        fi

        # Else only wait at most MAX_WAIT_TIME
        let "time_waited++"
        if [ "$time_waited" -gt "$MAX_WAIT_TIME" ]; then
            echo " ( Forcing stop since > $MAX_WAIT_TIME sec. elapsed )"
            kill -9 `head -1 $pid_file 2>/dev/null` > /dev/null 2>&1
            break
        fi
    done
    echo " ( Stopped )"
}

function exit_control () {
    # Test for interactive shell
    test -t 0 && stty $SHELL_CONFIG
    exit $1
}
function checkSensitiveFiles() {
     $RUBY -e "require '$CHORUS_HOME/app/services/sensitive_file_checker.rb'" -e "unless SensitiveFileChecker.check; puts(SensitiveFileChecker.errors); exit(1); end"

     SENSITIVE_FILE_EXIT_STATUS=$?

     if [ $SENSITIVE_FILE_EXIT_STATUS -eq 1 ]; then
        exit_control 1
     fi
}

#if [ "$RAILS_ENV" = "production" ]; then
    #checkSensitiveFiles
#fi
