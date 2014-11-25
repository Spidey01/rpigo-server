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

NAME=rpigo-powerd

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"

rpigo_log_setup powerd
rpigo_queue_setup

while read message_file
do
    rpigo_debug "message_file=$message_file"

    command="$(cat $message_file)"
    rpigo_debug "command was $command"

    case "$message_file" in
        */powerd.*)
            case "$command" in
                ${NAME}\ STOP)
                    rpigo_info "stopping process."
                    # d'oh how do we kill rpigo_queue_wait?
                    exit 0
                    ;;
                SHUTDOWN)
                    sudo -n shutdown -hP now
                    ;;
                REBOOT)
                    sudo -n reboot
                    ;;
                *)
                    echo "handle command: $command ..."
                    ;;
            esac
            ;;
        *)
            rpigo_debug "ignoring $message_file"
            ;;
    esac
done < <(rpigo_queue_wait)

