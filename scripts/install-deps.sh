#!/bin/sh

. ./lib/log.lib || {
    echo "Failed to source RPIGO logging library. Good bye."
    exit 127
}

if [ -f /etc/debian_version ]; then
    rpigo_info "Installing packages using Debian APT."
else
    rpigo_fatal "Don't know your OS. Send patches ;-)."
fi

installed() {
    type $*
}

apt_install() {
    local sudo

    if [ $(id -u) -ne 0 ]; then
        sudo='sudo'
    fi

    #sudo apt-get install --quiet --assume-yes --dry-run $*
    sudo apt-get install --quiet --assume-yes $*
}


if ! installed bash; then
    apt_install bash
fi


if ! installed sudo; then
    apt_install sudo
fi


if ! installed service; then
   rpigo_fatal "rpigo expects a 'service' utility as per sysvinit-utils." \
       ' You are missing that. Setup your init!'
fi

# Actually just this script needs it atm; 2014-11-19.
#if ! installed update-rc.d; then
#   rpigo_fatal "rpigo expects a 'update-rc.d' utility as per sysv-rc." \
#       ' You are missing that. Setup your init!'
#fi


if ! installed blkid; then
    apt_install util-linux
fi


if ! installed smbpasswd; then
    apt_install samba samba-common-bin
fi


if ! installed vsftpd; then
    apt_install vsftpd
    rpigo_info "Removing vsftpd from init.d services."
    sudo update-rc.d vsftpd remove
fi


if ! installed inotifywait ; then
    apt_install inotify-tools
fi


if ! installed avahi-publish-service; then
    apt_install avahi-utils
fi

# maybe lsb-base?

if ! installed start-stop-daemon; then
   rpigo_fatal "rpigo expects a 'start-stop-daemon' utility as per dpkg." \
       ' You are missing that. Do it yourself jerk!'
fi

