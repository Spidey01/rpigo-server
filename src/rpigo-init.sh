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


#
# usage: daemonize prog [arg ....]
#
# Execute program as a daemon.
#
daemonize() {
    #setsid $* >>rpigo.log 2>&1 < /dev/null &
    setsid $* < /dev/null &
}

export RPIGO_DEVELOPER="$(readlink -e $(dirname $0)/..)"
export RPIGO_BINDIR="${RPIGO_DEVELOPER}/src"
export RPIGO_LIBDIR="${RPIGO_DEVELOPER}/lib"
export RPIGO_SHAREDIR="${RPIGO_DEVELOPER}/share"
export RPIGO_QUEUE="/tmp/rpigo.queue"; mkdir /tmp/rpigo.queue
export RPIGO_CONFIGDIR="${RPIGO_DEVELOPER}/config"

.  "${RPIGO_LIBDIR}/log.lib"

rpigo_debug "RPIGO_DEVELOPER='$RPIGO_DEVELOPER'"

daemonize "${RPIGO_BINDIR}/rpigo-authd.sh" -o fifo

# WIP
#daemonize "${RPIGO_BINDIR}/rpigo-networkd.sh"

daemonize "${RPIGO_BINDIR}/rpigo-packaged.sh"
daemonize "${RPIGO_BINDIR}/rpigo-powerd.sh"
daemonize "${RPIGO_BINDIR}/rpigo-serviced.sh"
daemonize "${RPIGO_BINDIR}/rpigo-storaged.sh"

# WIP
#daemonize "${RPIGO_BINDIR}/rpigo-ftpd.sh"

rpigo_info "waiting on childrens."
wait
