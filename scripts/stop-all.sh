#!/bin/sh

for daemon in $(ls src/ | sed -e 's/.sh$//g' | grep -v rpigo-init | grep -v rpigo-authd); do
    $(dirname $0)/send.sh $* -- "$daemon STOP"
done

$(dirname $0)/send.sh $* -- "rpigo-authd STOP"
