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

NAME=rpigo-packaged

[ -r /etc/default/rpigo ] && . /etc/default/rpigo
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"
. "${RPIGO_LIBDIR}/config.lib"
. "${RPIGO_LIBDIR}/apt.lib"

# TODO: make sure RPIGO_CONFIGDIR is set.

MY_CONFIG="${RPIGO_CONFIGDIR}/packages.conf"
MY_CONFIGDIR="${RPIGO_CONFIGDIR}/packages.d"


# Really need to lib this up. Something like get_arg -3 {string}.
# Without echo|cut everywhere.
#
get_arg() {
    echo $* | cut -d' ' -f 3-
}


get_packageset() {
    local line package_set package_list

    line=$(config_grep "$1" "$MY_CONFIG")

    package_set="$(echo $line | sed -e 's/\s*=\s*/\n/g' | head -n 1)"
    package_list="$(echo $line | sed -e 's/\s*=\s*/\n/g' | tail -n 1)"

    #rpigo_debug "package set wanted: '$package_set'"
    #rpigo_debug "package list associated: '$package_list'"

    apt_get_packages "${MY_CONFIGDIR}/${package_list}"
}


install_packageset() {
    local package

    for package in $(get_packageset "$(get_arg $command)")
    do
        apt_install "$package"
    done
}


remove_packageset() {
    local package

    for package in $(get_packageset "$(get_arg $command)")
    do
        apt_remove "$package"
    done
}


while read message_file
do
    rpigo_debug "message_file=$message_file"

    command="$(cat $message_file)"
    rpigo_debug "command was $command"

    case "$message_file" in
        */packaged.*)
            case "$command" in
                ${NAME}\ STOP)
                    rpigo_info "stopping process."
                    exit 0
                    ;;
                PACKAGESET\ INSTALL\ *)
                    install_packageset $(get_packageset $(get_arg $command))
                    ;;
                PACKAGESET\ REMOVE\ *)
                    remove_packageset $(get_packageset $(get_arg $command))
                    ;;
                PACKAGESET\ UPDATE\ *)
                    #
                    # How do we want to handle this?
                    #
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

