#!/bin/bash

export RAILS_ENV=packaging

if [ "$HOSTNAME" = chorus-ci ]; then
  export GPDB_HOST=chorus-gpdb-ci
  export ORACLE_HOST=chorus-oracle
  export HAWQ_HOST=chorus-gphd20-2
fi

. script/ci/setup.sh
. script/ci/install_python.sh
echo "checking for an alpine package"
if [[ $(ls vendor/alpine/*.sh 2> /dev/null | wc -l) != "0" ]]; then
    echo "packaging with alpine"
    chmod +x vendor/alpine/*.sh
fi

rm -fr .bundle
bundle exec rake package:installer --trace
