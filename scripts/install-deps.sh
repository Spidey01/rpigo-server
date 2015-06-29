#!/bin/sh

if [ "$(id -u)" -ne 0 ]; then
    echo "You probably need to run this script as root."
    echo "Press enter to continue."
    echo "Press Control+C to exit."
    echo
    read OK
fi

apt-get install bash sudo util-linux samba samba-common-bin vsftpd minidlna inotify-tools avahi-utils eject
update-rc.d vsftpd remove
update-rc.d minidlna remove
