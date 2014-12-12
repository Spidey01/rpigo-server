#!/bin/sh

while getopts "dro:kq:" opt; do
    case $opt in
        d)
            developer=true
            ;;
        r)
            developer=false
            ;;
        o)
            how="$OPTARG"
            ;;
        k)
            want_kill=true
            ;;
        q)
            queue_here="$OPTARG"
            ;;
        \?)
            echo "Invalid option: _$OPTARG" >&2
            echo
            echo "usage: $0 [options]"
            echo
            printf "\t-d     => developer mode\n" 
            printf "\t-r     => release mode\n" 
            printf "\t-o HOW => see rpigo-authd -o.\n" 
            printf "\t-k     => kill after sending.\n" 
            printf "\t-q     => override RPIGO_QUEUE.\n" 
            echo
            exit $OPTERR
            ;;
    esac
done
shift `expr $OPTIND - 1`

fifo_send() {
    local queue fifo

    if [ "$developer" = "true" ]; then
        queue="${queue_here:-/tmp/rpigo.queue}"
    else
        queue="${queue_here:-/var/spool/rpigo/queue}"
    fi

    fifo="${queue}/$(ls "$queue" | grep fifo | tail -n 1)"

    echo $* > $fifo
}

echo "Sending '$*' to authd."
${how:-fifo}_send $*

if [ -n "$want_kill" ]; then
    echo hit enter to kill system
    read IDONTCARE
    $(dirname $0)/kill.sh
fi

