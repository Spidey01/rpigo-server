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

NAME=rpigo-ftpd

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"
. "${RPIGO_LIBDIR}/config.lib"
. "${RPIGO_LIBDIR}/util.lib"

# TODO: make sure RPIGO_CONFIGDIR is set.

MY_CONFIG="${RPIGO_CONFIGDIR}/ftp.conf"
MY_PIDDIR=/var/run/rpigo
vsftpd_pidfile="${MY_PIDDIR}/vsftpd.pid"
avahi_pid=

ftpd_start() {
    local ftp_port

    [ ! -d "$MY_PIDDIR" ] && rpigo_debug "mkdir $MY_PIDDIR" && sudo mkdir "$MY_PIDDIR"

    rpigo_info "Starting vsftpd."
    #
    # Note: this will --chdir / by default. So file paths have to be absolute
    #       paths or relative to /, not the CWD of this script.
    #
    sudo start-stop-daemon --start --make-pidfile --pidfile "${vsftpd_pidfile}" \
        --background --exec /usr/sbin/vsftpd -- "${MY_CONFIG}" -obackground=NO
    if [ $? -eq 0 ]; then
        rpigo_info "Publishing via DNS-SD."
        ftp_port="$(grep -v '#' "$MY_CONFIG" | grep 'listen_port=[0-9]*')"
        sudo avahi-publish-service "$(rpigo_unitname) FTP File Sharing" _ftp._tcp "${ftp_port:-21}" &
        avahi_pid=$!
    fi
}

ftpd_stop() {
    rpigo_info "Stopping vsftpd."
    sudo start-stop-daemon --stop --pidfile "${vsftpd_pidfile}" --name vsftpd
    sudo rm -f "${vsftpd_pidfile}"

    [ -n "$avahi_pid" ] \
        && rpigo_info "Unpublishing via DNS-SD." \
        && sudo kill "$avahi_pid"
}

#
# Enable if 
#
[ "$enable_ftpd" = true ] && ftpd_start


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

