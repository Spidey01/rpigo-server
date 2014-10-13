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
    #echo "setsid $* >/dev/null 2>&1 < /dev/null &"
    #setsid $* >>rpigo.log 2>&1 < /dev/null &
    setsid $* 
}

RPIGO_DEVELOPER="$(dirname $0)/.."
RPIGO_LIBDIR="${RPIGO_DEVELOPER}/lib"
RPIGO_QUEUE="/tmp/rpigo.queue"; mkdir /tmp/rpigo.queue

export RPIGO_DEVELOPER RPIGO_LIBDIR RPIGO_QUEUE

.  "${RPIGO_LIBDIR}/log.lib"

rpigo_debug "RPIGO_DEVELOPER='$RPIGO_DEVELOPER'"

daemonize "${RPIGO_DEVELOPER}/src/rpigo-authd.sh"
daemonize "${RPIGO_DEVELOPER}/src/rpigo-powerd.sh"

#"${RPIGO_DEVELOPER}/init/rpigo-authd" start

