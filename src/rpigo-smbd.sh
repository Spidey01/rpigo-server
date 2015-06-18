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


. "${RPIGO_LIBDIR}/config.lib"
. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"
. "${RPIGO_LIBDIR}/sudo.lib"
. "${RPIGO_LIBDIR}/util.lib"

rpigo_sudo_setup
rpigo_log_setup smbd


ensure_samba_running() {
    rpigo_debug 'Are samba services running?'
    if ! sudo -n service samba status; then
        rpigo_debug 'Starting samba service.'
        sudo -n service samba start
    fi
}


smb_enable() {
    ensure_samba_running

    [ -n "$storage_root" ] || {
        rpigo_error "Can't enable SMB because storage_root is not set."
        return 78 # EX_CONFIG
    }

    #
    # Floating defaults like this make me think config_eval() should have an
    # option to report error if [list of variables] is not found.
    #
    [ -z "$smb_share_name" ]    && smb_share_name="storage"
    [ -z "$smb_share_comment" ] && smb_share_comment="$(rpigo_unitname) SMB File Sharing}"
    [ -z "$smb_share_acl" ]     && smb_share_acl="Everyone:R"
    [ -z "$smb_share_guest" ]   && smb_share_guest="n"

    rpigo_info "Exporting usershare $storage_sharename via SMB."
    net usershare add \
        "$smb_share_name" "$storage_root" \
        "$smb_share_comment" \
        "$smb_share_acl" guest_ok="$smb_share_guest_ok"

    [ $? -eq 0 ] && clean_up_needed=true
}


smb_disable() {
    [ -n "$storage_root" ] || {
        rpigo_error "Can't disable SMB because storage_root is not set."
        return 78 # EX_CONFIG
    }

    rpigo_info "Unexporting usershare $storage_sharename via SMB."
    net usershare delete "$storage_sharename"
}


for config_to_load in \
    "${RPIGO_CONFIGDIR}/storage.conf" \
    "${RPIGO_CONFIGDIR}/smb.conf"
do
    #
    # While config_eval() supports multiple files as input.
    # We want the greater diagnostics of this loop.
    #
    if ! config_eval "$config_to_load"; then
        rpigo_error "error parsing configuration file '${config_to_load}'."
    fi
done
[ -n "$storage_root" ] \
    || rpigo_warn "storage_root may not have been set in storage.conf?"


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
                    smb_disable
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

