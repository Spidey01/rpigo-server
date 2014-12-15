
For general info run `make help` in this directory. Here's a snapshot of it:

    $ make help
    Available targets and variables are as follows:

        * help: You're reading it.
        * install: Install to /usr/local
        * uninstall: uninstall files but leave /etc/xdg/rpigo
        * purge: uninstall + purge /etc/xdg/rpigo
        * useradd: do a useradd for rpigo.
        * userdel: do a userdel for rpigo.

    You can change install location by setting PREFIX=yourpath.
    I.e.$ make PREFIX=/usr install

    DESTDIR will be respected as expected if given.

    RPIGO_USERNAME can be set to the username to run as.
    The useradd, userdel, and various install dependencies
    will respect this variable.


In most cases you probably want to do this as root:

    # make useradd install
    # update-rc.d rpigo defaults
    # service rpigo start

If you're not root then prefix the commands with sudo.
If that doesn't work then contact your real system admin 8-).

