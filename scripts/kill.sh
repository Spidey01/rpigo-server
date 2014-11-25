#!/bin/sh

$(dirname $0)/stop-all.sh $*

pkill inotifywait

if [ "$1" = "-d" ]; then
    rm -rf /tmp/rpigo.queue
elif [ "$1" = "-r" -o -z "$1" ]; then
    rm -rf /var/spool/rpigo/queue
fi
