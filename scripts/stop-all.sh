#!/bin/sh

kill_it() {
    local fifo
    fifo="/tmp/rpigo.queue/$(ls /tmp/rpigo.queue | grep fifo | tail -n 1)"
    echo "$1 STOP" > $fifo
}

for daemon in $(ls src/ | sed -e 's/.sh$//g' | grep -v rpigo-init | grep -v rpigo-authd); do
    kill_it $daemon
done

kill_it rpigo-authd
