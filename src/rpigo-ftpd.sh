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
# ftpd -- File Transfer Protocol support daemon.
#
NAME=rpigo-ftpd

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/sudo.lib"
. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"
. "${RPIGO_LIBDIR}/config.lib"
. "${RPIGO_LIBDIR}/util.lib"

rpigo_sudo_setup
rpigo_log_setup ftpd

# TODO: make sure RPIGO_CONFIGDIR is set.

MY_CONFIG="${RPIGO_CONFIGDIR}/ftp.conf"
vsftpd_pidfile="${RPIGO_RUNDIR}/vsftpd.pid"
avahi_pid=

# Default location root if not specified in the $MY_CONFIG.
#
storage_root="/media"

ftpd_start() {
    local ftp_port

    [ ! -d "$RPIGO_RUNDIR" ] && rpigo_debug "mkdir $RPIGO_RUNDIR" && rpigo_sudo mkdir "$RPIGO_RUNDIR"

    # This is set because Debian's init script for vsftp makes it before launch
    # and the default is under the /run tmpfs.
    #
    if config_grep -q "secure_chroot_dir" "$MY_CONFIG"; then
        mkdir -p $(config_grep "secure_chroot_dir" "$MY_CONFIG")
    fi

    rpigo_info "Starting vsftpd."
    #
    # Note: this will --chdir / by default. So file paths have to be absolute
    #       paths or relative to /, not the CWD of this script.
    #
    rpigo_sudo start-stop-daemon --start --make-pidfile --pidfile "${vsftpd_pidfile}" \
        --background --exec /usr/sbin/vsftpd -- "${MY_CONFIG}" \
            -obackground=NO \
            -oanon_root="$storage_root" -olocal_root="$storage_root"
    if [ $? -eq 0 ]; then
        rpigo_info "Publishing via DNS-SD."
        ftp_port="$(grep -v '#' "$MY_CONFIG" | grep 'listen_port=[0-9]*')"
        rpigo_sudo avahi-publish-service "$(rpigo_unitname) FTP File Sharing" _ftp._tcp "${ftp_port:-21}" &
        avahi_pid=$!
    fi
}

ftpd_stop() {
    rpigo_info "Stopping vsftpd."
    rpigo_sudo start-stop-daemon --stop --pidfile "${vsftpd_pidfile}" --name vsftpd
    rpigo_sudo rm -f "${vsftpd_pidfile}"

    [ -n "$avahi_pid" ] \
        && rpigo_info "Unpublishing via DNS-SD." \
        && rpigo_sudo kill "$avahi_pid"
}


storage_conf="${RPIGO_CONFIGDIR}/storage.conf"
if ! config_eval "$storage_conf"; then
    rpigo_error "error parsing configuration file '${storage_conf}'."
fi

#
# Enable if 
#
[ "$enable_ftpd" = true ] && ftpd_start

rpigo_queue_setup

while read message_file
do
    rpigo_debug "message_file=$message_file"

    command="$(cat $message_file)"
    rpigo_debug "command was $command"

    case "$message_file" in
        */ftpd.*)
            case "$command" in
                ${NAME}\ STOP)
                    rpigo_info "ftpd_stopping process."
                    #
                    # Is it a greater evil to leak the process or risk breaking
                    # a file transfer? -- I expect leaking is more worry here.
                    #
                    ftpd_stop
                    rpigo_info "stopping process."
                    exit 0
                    ;;
                FTPD\ START)
                    ftpd_start
                    ;;
                FTPD\ STOP)
                    ftpd_stop
                    ;;
                FTPD\ RESTART)
                    ftpd_stop
                    ftpd_start
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

