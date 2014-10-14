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

NAME=rpigo-storaged

[ -r /etc/default/$NAME ] && . /etc/default/$NAME
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/log.lib"
#. "${RPIGO_LIBDIR}/queue.lib"


my_exit_trap() {
    [ -n "$MONITOR_PID" ] && pkill -P $MONITOR_PID inotifywait
}

trap 'my_exit_trap' EXIT

storage_root="${storage_root:-/media}"

while read new_device
do
    # kill our inotifywait via our EXIT trap.
    # Obviously it only works if we've gotten output from inotifywait before exiting.
    #
    [ -z "$MONITOR_PID" ] && MONITOR_PID=$!

    rpigo_debug "new_device=$new_device"

    if echo "$new_device" | grep -q -E '/dev/sd[a-z]+[0-9]+$'; then
        rpigo_info "attempt mounting $new_device"
        #
        # determine the volume name to use as a mount point.
        #
        if [ -n "$storage_name_format" \
             -a \( "$storage_name_format" != "UUID" -a "$storage_name_format" != "LABEL" \) ]
         then
            rpigo_error "unsupported storage_name_format=${storage_name_format}."
            continue
        fi
        volume_name="$(sudo blkid -o export "$new_device" | grep "$storage_name_format" | cut -d '=' -f 2)"

        # fail safe in case storage_name_format=LABEL and there is no label.
        [ -z "$storage_name_format" ] && storage_name_format="$(basename "$new_device")"

        #
        # I'm just going to trust blkid to tell us the format. And warn if mkfs.that doesn't exist.
        #
        volume_format="$(blkid blkid -o export "$new_device" | grep "TYPE" | cut -d '=' -f 2)"
        type mkfs."${volume_format}" >/dev/null 2>/dev/null || rpigo_warn "mkfs.$volume_format doesn't exist."

        #
        # Handle mount options.
        #
        [ -n "$storage_mount_ro" ]      && volume_options="${volume_options},ro"
        [ -n "$storage_mount_noexec" ]  && volume_options="${volume_options},noexec"
        [ -n "$storage_mount_nodev" ]   && volume_options="${volume_options},nodev"
        [ -n "$storage_mount_nosuid" ]  && volume_options="${volume_options},nosuid"
        [ -n "$volume_options" ]        && volume_options="-o defaults${volume_options}"
        [ -n "$storage_mount_options" ] && volume_options="${volume_options} ${storage_mount_options}"

        echo sudo mount -t "$volume_format" "$volume_options" "$new_device" "${storage_root}/${volume_name}"
    fi
done < <(inotifywait -m -q -e create --format "%w%f" /dev)


# while read message_file
# do
#     rpigo_debug "message_file=$message_file"
# 
#     command="$(cat $message_file)"
#     rpigo_debug "command was $command"
# 
#     case "$message_file" in
#         */storaged.*)
#             case "$command" in
#                 ${NAME}\ STOP)
#                     rpigo_info "stopping process."
#                     ;;
#                 *)
#                     echo "handle command: $command ..."
#                     ;;
#             esac
#             ;;
#         *)
#             rpigo_debug "ignoring $message_file"
#             ;;
#     esac
# done < <(rpigo_queue_wait)
