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

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/config.lib"
. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"
. "${RPIGO_LIBDIR}/sudo.lib"

rpigo_sudo_setup
rpigo_log_setup storaged


#
# Configuration directives we care about.
#
my_config="${RPIGO_CONFIGDIR}/storage.conf"

#
# Default location to mount media if not specified in the $my_config.
#
storage_root="/media"

#
# Default uid/gid of mount points if not specified in $my_config.
#
storage_mount_uid="$(id -u)"
storage_mount_gid="$(id -g)"


is_allowed_device() {
    echo "$1" | grep -q -E '/dev/sd[a-z]+[0-9]+$'
}


is_in_storage_root() {
    local w
    w="${storage_root}/${1}"
    [ -d "$w" ] && grep -q "$w" /proc/mounts
}


#
# Mount sepcified device IAW config.
#
mount_device() {
    local fn new_device volume_name volume_format volume_options mount_point mount_command

    fn="${FUNCNAME[0]}()"
    new_device="$1"

    rpigo_debug "$fn: new_device=$new_device"

    if is_allowed_device "$new_device"; then
        rpigo_info "$fn: attempt mounting $new_device"

        # Force a default if not set.
        [ -z "$storage_name_format" ] && storage_name_format="LABEL"

        #
        # determine the volume name to use as a mount point.
        #
        if [ -n "$storage_name_format" \
             -a \( "$storage_name_format" != "UUID" -a "$storage_name_format" != "LABEL" \) ]
         then
            rpigo_error "$fn: unsupported storage_name_format=${storage_name_format}."
            continue
        fi
        volume_name="$(rpigo_sudo blkid -o export "$new_device" | grep "^${storage_name_format}=" | cut -d '=' -f 2)"

        # fail safe in case storage_name_format=LABEL and there is no label.
        [ -z "$volume_name" ] && volume_name="$(basename "$new_device")"

        #
        # I'm just going to trust blkid to tell us the format. And warn if mkfs.that doesn't exist.
        #
        # XXX:
        #       On util-linux 2.25.2-4ubuntu2 on my ODroid-XU4's Ubuntu 15.04
        #       image, DEVNAME is output along with TYPE when doing:
        #
        #               blkid -o export -s TYPE. So just do a greppy here.
        #
        #       So let's work around it here \o/
        #
        volume_format="$(rpigo_sudo blkid -o export -s TYPE "$new_device" | grep "^TYPE=" | cut -d '=' -f 2)"
        type mkfs."${volume_format}" >/dev/null 2>/dev/null || rpigo_warn "$fn: mkfs.$volume_format doesn't exist."

        #
        # these mount options have dynamic defaults if not in the config.
        #
        [ -z "$storage_mount_vfat_uid" ] && storage_mount_vfat_uid=$storage_mount_uid
        [ -z "$storage_mount_vfat_gid" ] && storage_mount_vfat_gid=$storage_mount_gid

        #
        # Handle mount options.
        #
        [ -n "$storage_mount_ro" ]      && volume_options="${volume_options},ro"
        [ -n "$storage_mount_noexec" ]  && volume_options="${volume_options},noexec"
        [ -n "$storage_mount_nodev" ]   && volume_options="${volume_options},nodev"
        [ -n "$storage_mount_nosuid" ]  && volume_options="${volume_options},nosuid"
        [ -n "$volume_options" ]        && volume_options="-o defaults${volume_options}"

        if [ "$volume_format" = "vfat" ]; then
            [ -n "$storage_mount_vfat_uid" ]    && volume_options="${volume_options},uid=$storage_mount_vfat_uid"
            [ -n "$storage_mount_vfat_gid" ]    && volume_options="${volume_options},gid=$storage_mount_vfat_gid"
            [ -n "$storage_mount_vfat_dmask" ]  && volume_options="${volume_options},dmask=$storage_mount_vfat_dmask"
            [ -n "$storage_mount_vfat_fmask" ]  && volume_options="${volume_options},fmask=$storage_mount_vfat_fmask"
        fi


        #
        # Get it done ;).
        #
        mount_point="${storage_root}/${volume_name}"
        rpigo_info "mount point for \"$new_device\" is \"$mount_point\""
        rpigo_sudo mkdir -m 0700 -p "$mount_point" && rpigo_info "created mount point $mount_point"

        mount_command="rpigo_sudo mount -t \"$volume_format\" $volume_options $storage_mount_options \"$new_device\" \"$mount_point\""

        rpigo_debug "mount command => '$mount_command'"

        if ! eval $mount_command
        then
            rpigo_error "Looks like mounting '$new_device' on '$mount_point' failed."
        fi

        # ensure ext mount points get correct permissions.
        rpigo_sudo chown "${storage_mount_uid}:${storage_mount_gid}" "$mount_point"
    fi
}


#
# Mount all them things!
#
mount_all() {
    local device

    rpigo_debug "${FUNCNAME[0]}(): searching /dev for allowed devices  missing in ${storage_root}."

    for device in /dev/*; do
        if is_allowed_device "$device"; then
            mount | grep -q "^${device}" && continue # already mounted.
            mount_device "$device"
        fi
    done
}


#
# Eject a specified disk from all mount points.
#
# Takes basename (e.g. sda1) as an argument.
#
do_eject() {
    local fn device point

    fn="${FUNCNAME[0]}()"

    device="$1"

    rpigo_info "ejecting '$device'"

    if is_allowed_device "/dev/${device}"; then
        rpigo_sudo eject "/dev/${device}"
    elif is_in_storage_root "${device}"; then
        rpigo_sudo eject "${storage_root}/${device}"
    else
        rpigo_error "$fn: $device is not an allowed device or not mounted under ${storage_root}."
        return 64 # EX_USAGE
    fi
}


if ! config_eval "$my_config"; then
    rpigo_error "error parsing configuration file '${my_config}'."
fi

rpigo_queue_setup

while read device_or_message
do
    rpigo_debug "device_or_message=$device_or_message"

    if grep -q /dev/ <<< "$device_or_message"; then
        mount_device "$device_or_message"
    else
        #
        # It's a message file in the queue.
        #
        command="$(cat $device_or_message 2>/dev/null)"
        rpigo_debug "command was $command"

        case "$device_or_message" in
            */storaged.*)
                case "$command" in
                    ${NAME}\ STOP)
                        rpigo_info "stopping process."
                        # self kill with childrens.
                        kill -- -$$
                        ;;
                    MOUNT\ ALL)
                        mount_all
                        ;;
                    EJECT\ *)
                        do_eject "$(echo "$command" | awk '{ print $2 }')"
                        ;;
                    *)
                        rpigo_warn "TODO: handle command: $command ..."
                        ;;
                esac
                ;;
            # See comments below loop.
            #${NAME}_*_pid\ [0-9]*)
            #    MONITOR_PIDS="$MONITOR_PIDS $(echo $device_or_message | awk '{print $2}')"
            #    ;;
            *)
                rpigo_debug "ignoring $device_or_message"
                ;;
        esac
    fi

done < <(rpigo_queue_wait & inotifywait -m -q -e create --format "%w%f" /dev & wait)
#
# wait so the subshell sticks around for the loop.
#
# We can't get the exact ppid of rpi_queue_wait& with $!; so we just kill ourself by -$$.
#
# We probably could wait on inotifywait's $! alone to deal with it via
# MONITOR_PIDS and futher # forgoe the rpi_queue_wait->inotifywait cleanup
# until such time as deciding on # one in general.
#

