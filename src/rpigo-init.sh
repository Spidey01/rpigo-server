#!/usr/bin/env bash
#-
# Copyright (c) 2014-current, Terry Mathew Poulin <BigBoss1964@gmail.com>
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# rpigo-init -- Daemon Horde Initializer
#

# Source system defaults.
[ -r /etc/default/rpigo ] && . /etc/default/rpigo

#
# usage: rpigo-init.sh [options]
#
while getopts "dvL:" opt; do
    case $opt in
        d)
            # enable developer mode.
            export RPIGO_DEVELOPER=true
            ;;
        v)
            # max logging.
            export RPIGO_LOGLEVEL=999
            ;;
        L)
            export RPIGO_LOGLEVEL="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit $OPTERR
            ;;
    esac
done
shift `expr $OPTIND - 1`


if [ -z "$RPIGO_DEVELOPER" ]
then # RELEASE / INSTALLED MODE.
echo release mode
    [ -z "$RPIGO_PREFIX" ] \
        && RPIGO_PREFIX=/usr/local \
        && echo "Defaulting RPIGO_PREFIX=$RPIGO_PREFIX"

    export RPIGO_BINDIR="${RPIGO_PREFIX}/bin"
    export RPIGO_LIBDIR="${RPIGO_PREFIX}/lib/rpigo"
    export RPIGO_SHAREDIR="${RPIGO_PREFIX}/share/rpigo"

    export RPIGO_CONFIGDIR="/etc/xdg/rpigo"
    export RPIGO_SPOOLDIR="/var/spool/rpigo"
    export RPIGO_RUNDIR="/var/run/rpigo"
    export RPIGO_LOGDIR="/var/log/rpigo"

    [ -n "$RPIGO_LOGLEVEL" ] || export RPIGO_LOGLEVEL=3

else # DEVELOPER / SOURCE MODE.
echo developer mode
    #
    # Force the prefix to our working copy.
    #
    export RPIGO_PREFIX="$(readlink -e $(dirname $0)/..)"
    export RPIGO_BINDIR="${RPIGO_PREFIX}/src"
    export RPIGO_LIBDIR="${RPIGO_PREFIX}/lib"
    export RPIGO_SHAREDIR="${RPIGO_PREFIX}/share"
    export RPIGO_CONFIGDIR="${RPIGO_PREFIX}/config"

    export RPIGO_SPOOLDIR="/tmp/rpigo.spool"; mkdir $RPIGO_SPOOLDIR
    export RPIGO_QUEUE="/tmp/rpigo.queue"; mkdir "$RPIGO_QUEUE"
    export RPIGO_RUNDIR="/tmp/rpigo.run"
    export RPIGO_LOGDIR="/tmp/rpigo.log"

    [ -n "$RPIGO_LOGLEVEL" ] || export RPIGO_LOGLEVEL=4

    #
    # Used because sources are named .sh but installed in release mode the
    # extension gets dropped from the filename.
    #
    SCRIPT_EXT=.sh
fi

# Variables that MUST be set and exported.
#
for rpigo_var in \
    RPIGO_PREFIX \
    RPIGO_BINDIR \
    RPIGO_LIBDIR \
    RPIGO_SHAREDIR \
    RPIGO_CONFIGDIR \
    RPIGO_SPOOLDIR
do
    if eval test -z "\$$rpigo_var"; then
        echo "EX_SOFTWARE: required variable $rpigo_var not set in code."
        exit 70
    fi
    eval export $rpigo_var
done

.  "${RPIGO_LIBDIR}/log.lib"
.  "${RPIGO_LIBDIR}/util.lib"
.  "${RPIGO_LIBDIR}/sudo.lib"
.  "${RPIGO_LIBDIR}/queue.lib"

#
# Oh magical sudo, we assume thy configuration is sane.
# Or die here ASAP.
#
rpigo_sudo_setup

#
# Setup a central log file before our per daemon logs are spawned.
#
rpigo_log_setup init

rpigo_debug "RPIGO_DEVELOPER='$RPIGO_DEVELOPER'"


[ ! -d "$RPIGO_RUNDIR" ] && rpigo_debug "mkdir $RPIGO_RUNDIR" && rpigo_sudo mkdir "$RPIGO_RUNDIR"
echo $$ > "${RPIGO_RUNDIR}/init.pid"

# Needed so stopall() can access the queue.
rpigo_queue_setup


#
# usage: daemonize prog [arg ....]
#
# Execute program as a daemon.
#
daemonize() {
    #setsid $* >>rpigo.log 2>&1 < /dev/null &
    rpigo_debug "executing 'setsid $* < /dev/null &'"
    setsid $* < /dev/null &
}

startall() {
    local daemon startup_script
    rpigo_debug "startall()"

    daemonize "${RPIGO_BINDIR}/rpigo-authd${SCRIPT_EXT}" -o fifo
    for daemon in $daemons_list_in_start_order
    do
        daemonize "${RPIGO_BINDIR}/${daemon}${SCRIPT_EXT}"
    done

    # WIP
    #daemonize "${RPIGO_BINDIR}/rpigo-networkd${SCRIPT_EXT}"
    #daemonize "${RPIGO_BINDIR}/rpigo-printerd${SCRIPT_EXT}"

    startup_script="${RPIGO_CONFIGDIR}/commands.startup"
    if [ -f "$startup_script" ]; then
        rpigo_debug "sleeping before startup script runs"
        sleep 5
        rpigo_info "Running startup commands from ${startup_script}."
        rpigo_queue_script "$startup_script"
    fi
}

stopall() {
    local daemon shutdown_script stop_command

    rpigo_debug "stopall()"

    shutdown_script="${RPIGO_CONFIGDIR}/commands.shutdown"
    if [ -f "$shutdown_script" ]; then
        rpigo_info "Running shutdown commands from ${shutdown_script}."
        rpigo_queue_script "$shutdown_script"
    fi

    for daemon in $daemons_list_in_stop_order
    do
        #
        # Inject STOP command.
        #
        stop_command="rpigo-${daemon} STOP"
        rpigo_info "Sending '$stop_command' to daemon '$daemon'."
        rpigo_queue_send "$daemon" "$stop_command"
    done

    # authd does not watch the message queue. So we have to provide its stop
    # message via the authentication backend. This is kind of a bad coupling
    # but it is sufficent for now.
    #
    echo rpigo-authd STOP > "${RPIGO_SPOOLDIR}/authd/$(ps xa | grep rpigo-authd | grep -v grep | awk '{print $1}').fifo"


    #
    # Is it safe to do this in a SIGTERM handler?
    #
    rpigo_debug "SIGTERM handler: waiting on childrens."
    wait
    rpigo_debug "SIGTERM handler: DONE."
}

#
# Ordered lists of daemons to start or stop.
# Sans authd!
#
daemons_list_in_start_order="\
    rpigo-powerd \
    rpigo-storaged \
    rpigo-ftpd \
    rpigo-smbd \
    rpigo-dlnad \
    rpigo-serviced \
    rpigo-packaged \
"
daemons_list_in_stop_order="$(echo $daemons_list_in_start_order | sed -e 's/\s/\n/g' | tac | cut -d'-' -f 2-)"

#
# Setup a trap to stop childrens on SIGTERM.
#
trap stopall TERM
startall

rpigo_info "waiting on childrens."
wait
rpigo_info "Exiting process."

