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
# authd -- command authentication and dispatch daemon.
#
NAME=rpigo-authd

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
rpigo_log_setup authd

handle_own_commands() {
    case "$1" in
        ${NAME}\ STOP)
            rpigo_info "stopping process."
            $command_teardown
            exit 0
            ;;
    esac
}


while getopts "o:" opt; do
    case $opt in
        o)
            authd_backend="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit $OPTERR
            ;;
    esac
done
shift `expr $OPTIND - 1`

#
# Setup the backend and a command_paser= to a suitable callback..
#

# XXX needs more error checking!
command_backend="${RPIGO_LIBDIR}/authd/${authd_backend}.lib"
command_setup="${authd_backend}_command_setup"
command_teardown="${authd_backend}_command_teardown"
command_parser="${authd_backend}_command_parser"

case "$authd_backend" in
    fifo)
        ;;
    tcp)
        ;;
    *)
        rpigo_error "unknown backend: ${authd_backend:-no default set}"
        ;;
esac



rpigo_debug "command_backend lib is $command_backend"
rpigo_debug "command_setup function is $command_setup"
rpigo_debug "command_teardown function is $command_teardown"
rpigo_debug "command_parser function is $command_parser"

# TODO: error handling.
. "$command_backend"


# XXX Don't use 'if !' here. The logical negate changes $? to 0.
$command_setup || {
    WTF="$?"
    rpigo_error "${command_setup}() returned $WTF exit status."
    exit $WTF
}

while $command_parser COMMAND
do
    rpigo_debug "COMMAND='$COMMAND'"

    to_daemon="$(rpigo_which_daemon "$COMMAND")"

    if [ -z "$to_daemon" ]; then
        rpigo_warn "unknown command: '$COMMAND'"
        continue # MAGIC!
    fi
    echo "We want to send '$COMMAND' to '$to_daemon'"

    # magic: handle our own commands.
    if [ "$to_daemon" = "authd" ]; then
        handle_own_commands "$COMMAND"
        continue
    fi

    rpigo_queue_send "$to_daemon" $COMMAND
done

$command_teardown
