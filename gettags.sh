#!/bin/bash
SCRIPTS_PATH=$(cd $(dirname "${BASH_SOURCE}") && pwd -P)
python ${SCRIPTS_PATH}/gettags.py -d $1 -u $2 -p $3 -project $4 -o $5
