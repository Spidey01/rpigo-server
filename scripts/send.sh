#!/bin/sh

while getopts "dro:kq:f:" opt; do
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
        f)
            fifo_here="$OPTARG"
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
            printf "\t-f     => force this fifo file.\n" 
            echo
            exit $OPTERR
            ;;
    esac
done
shift `expr $OPTIND - 1`

fifo_send() {
    local queue fifo pid

    pid="$(ps xa | grep rpigo-authd | grep -v grep | awk '{print $1}')"

    if [ "$developer" = "true" ]; then
        queue="${queue_here:-/tmp/rpigo.queue}"
        fifo="${fifo_here:-/tmp/rpigo.spool/${pid}.fifo}"
    else
        queue="${queue_here:-/var/spool/rpigo/queue}"
        fifo="${fifo_here:-/var/spool/rpigo/authd/${pid}.fifo}"
    fi

    if [ ! -e "$fifo" ]; then
        echo "Can't find the FIFO file."
        echo "Try again with -f FIFO."
        exit 127
    fi

    echo $* > "$fifo"
}

echo "Sending '$*' to authd."
${how:-fifo}_send $*

# FIXME: handle -r and -d
if [ -n "$want_kill" ]; then
    echo hit enter to kill system
    read IDONTCARE
    $(dirname $0)/kill.sh
fi

