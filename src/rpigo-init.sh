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
# rpigo-init -- bootstrap the system from source or init scripts.
#

# Source system defaults.
[ -r /etc/default/rpigo ] && . /etc/default/rpigo

#
# usage: rpigo-init.sh [options]
#
while getopts "d" opt; do
    case $opt in
        d)
            # enable developer mode.
            export RPIGO_DEVELOPER=true
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

rpigo_debug "RPIGO_DEVELOPER='$RPIGO_DEVELOPER'"

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

daemonize "${RPIGO_BINDIR}/rpigo-authd${SCRIPT_EXT}" -o fifo

# WIP
#daemonize "${RPIGO_BINDIR}/rpigo-networkd${SCRIPT_EXT}"

daemonize "${RPIGO_BINDIR}/rpigo-packaged${SCRIPT_EXT}"
daemonize "${RPIGO_BINDIR}/rpigo-powerd${SCRIPT_EXT}"
daemonize "${RPIGO_BINDIR}/rpigo-storaged${SCRIPT_EXT}"

daemonize "${RPIGO_BINDIR}/rpigo-serviced${SCRIPT_EXT}"
daemonize "${RPIGO_BINDIR}/rpigo-ftpd${SCRIPT_EXT}"
daemonize "${RPIGO_BINDIR}/rpigo-smbd${SCRIPT_EXT}"
# WIP
#daemonize "${RPIGO_BINDIR}/rpigo-printerd${SCRIPT_EXT}"

rpigo_info "waiting on childrens."
wait
