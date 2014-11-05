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

NAME=rpigo-authd

[ -r /etc/default/$NAME ] && . /etc/default/$NAME
if [ -z "$RPIGO_LIBDIR" ]; then
    echo "${NAME}/wtf: RPIGO_LIBDIR not set. Aborting."
    exit 127
fi


. "${RPIGO_LIBDIR}/log.lib"
. "${RPIGO_LIBDIR}/queue.lib"


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

$command_setup

while $command_parser COMMAND
do
    rpigo_debug "COMMAND='$COMMAND'"

    to_daemon=""

    #
    # Figure out which daemon to dispatch command to.
    #
    for list in ${RPIGO_SHAREDIR}/*.cmds
    do
        rpigo_debug "command pattern list=$list"

        while read basic_pattern
        do
            # skip comments ^_^.
            echo "$basic_pattern" | grep -qE '^#' && continue

            if echo "$COMMAND" | grep -q "$basic_pattern"; then
                to_daemon="$(basename $list | cut -d. -f 1)"
                break
            fi
        done < "$list"
    done

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

    #
    # Calculate some valid name for message_file.
    # We are the ONLY program who creates these.
    #

    # by modification time
    #last_message_number=$(ls -t ${RPIGO_QUEUE}/${to_daemon}.[0-9]* | tail -n 1 | xargs basename | cut -d. -f 2 2>/dev/null)
    # by name
    last_message_number=$(ls ${RPIGO_QUEUE}/${to_daemon}.[0-9]* | sort | tail -n 1 | xargs basename | cut -d. -f 2 2>/dev/null)

    [ -z $last_message_number ] && last_message_number=-1

    message_file="${RPIGO_QUEUE}/${to_daemon}.$(expr $last_message_number + 1)"
    
    rpigo_debug "message_file will be: $message_file"
    rpigo_debug "COMMAND will be: $COMMAND"

    echo "$COMMAND" > $message_file
    #rpigo_debug "rm -f => $message_file"
done

$command_teardown
