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

NAME=rpigo-dlnad

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/sudo.lib"
. "${RPIGO_LIBDIR}/config.lib"
. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"
. "${RPIGO_LIBDIR}/util.lib"

rpigo_sudo_setup
rpigo_log_setup dlnad
rpigo_warn "minidlna 1.0.24 was rejecting -f config syntax as of 2014-12-12. YMMV."

#
# Configuration directives we care about.
#
my_config="${RPIGO_CONFIGDIR}/minidlna.conf"
storage_config="${RPIGO_CONFIGDIR}/storage.conf"

#
# Default location to mount media if not specified in the $storage_config or
# /etc/defaults/rpigo files.
#
storage_root="${storage_root:-/media}"


clean_up_needed=

minidlna_pidfile="${RPIGO_RUNDIR}/minidlna.pid"


dlna_enable() {
    local name

    name="$(rpigo_unitname)"

    [ ! -d "$RPIGO_RUNDIR" ] && rpigo_debug "mkdir $RPIGO_RUNDIR" && sudo -n mkdir "$RPIGO_RUNDIR"

    rpigo_info "Starting minidlna."
    #
    # Note: this will --chdir / by default. So file paths have to be absolute
    #       paths or relative to /, not the CWD of this script.
    #
    echo sudo -n start-stop-daemon --start --pidfile "${minidlna_pidfile}" \
        --exec /usr/bin/minidlna -- \
            -f "${my_config}" -P "${minidlna_pidfile}" \
            -s "$(get_serial_number)"
    # Should we report a -m "model number" ???

    #if [ $? -eq 0 ]; then
    #fi
}


dlna_disable() {
    rpigo_info "Stopping minidlna."
    sudo -n start-stop-daemon --stop --pidfile "${minidlna_pidfile}" --name minidlna
    sudo -n rm -f "${minidlna_pidfile}"
}


if ! config_eval "$storage_config"; then
    rpigo_error "error parsing configuration file '${storage_config}'."
fi

[ "$enable_dlna" = true ] && dlna_enable

rpigo_queue_setup

while read message_file
do
    rpigo_debug "message_file=$message_file"

    command="$(cat $message_file)"
    rpigo_debug "command was $command"

    case "$message_file" in
        */dlnad.*)
            case "$command" in
                ${NAME}\ STOP)
                    [ -n $clean_up_needed ] && dlna_disable
                    exit 0
                    ;;
                DLNA\ ENABLE)
                    dlna_enable
                    ;;
                DLNA\ DISABLE)
                    dlna_disable
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

