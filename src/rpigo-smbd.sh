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

NAME=rpigo-smbd

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/sudo.lib"
. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/util.lib"
. "${RPIGO_LIBDIR}/queue.lib"

rpigo_sudo_setup
rpigo_log_setup smbd

storage_root="/media"
storage_sharename="storage"

clean_up_needed=

ensure_samba_running() {
    rpigo_debug 'Are samba services running?'
    if ! sudo -n service samba status; then
        rpigo_debug 'Starting samba service.'
        sudo -n service samba start
    fi
}

smb_enable() {
    local name
    name="$(rpigo_unitname)"

    ensure_samba_running

    rpigo_info "Exporting usershare $storage_sharename via SMB."
    net usershare add \
        "$storage_sharename" "$storage_root" "$name SMB File Sharing" 

    [ $? -eq 0 ] && clean_up_needed=true
}

smb_disable() {
    rpigo_info "Unexporting usershare $storage_sharename via SMB."
    net usershare delete "$storage_sharename"
}


[ "$enable_smb" = true ] && smb_enable

rpigo_queue_setup

while read message_file
do
    rpigo_debug "message_file=$message_file"

    command="$(cat $message_file)"
    rpigo_debug "command was $command"

    case "$message_file" in
        */smbd.*)
            case "$command" in
                ${NAME}\ STOP)
                    [ -n $clean_up_needed ] && smb_disable
                    rpigo_info "stopping process."
                    exit 0
                    ;;
                SMB\ ENABLE)
                    smb_enable
                    ;;
                SMB\ DISABLE)
                    smb_disable
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

