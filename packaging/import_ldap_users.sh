#!/bin/sh
bin=`readlink "$0"`
if [ "$bin" == "" ]; then
 bin=$0
fi
bin=`dirname "$bin"`
bin=`cd "$bin"; pwd`

. "$bin"/chorus-config.sh

export PATH=$PATH:$CHORUS_HOME/bin

$CHORUS_HOME/postgres/bin/pg_ctl -D $CHORUS_HOME/postgres-db  status | grep "is running"  > /dev/null

if [ $? != 0 ]; then
    echo "Chorus must be running before importing LDAP users. Please start Chorus and try again."
    exit 1
fi

echo "Importing LDAP users to Chorus"
echo "==============================\n"
$RAKE ldap:import_users
exit 0

