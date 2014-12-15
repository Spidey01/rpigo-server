
Development notes are in [my Evernote](http://www.evernote.com/l/AIBBnV16K9ZF9LcGfxjjBoMoooO77pWrTBg/).

Code is structured like this:

  - config
    + Default configuation files.
  - init
    + Init system script(s).
  - lib
    + Library code shared among daemons.
  - logrotate.conf
    + Configuration file for logrotate.
  - Makefile
    + Assistance in installation and removal.
  - scripts
    + Helpful shell scripts for development mode.
  - share
    + Data files.
  - src
    + Source code for the various daemons.
  - sudoers
    + Configuration file for sudo.

The place to start reading is src/rpigo-init.sh.

Determining commands is done by src/rpigo-authd.sh. The only backends right now are a named pipe (FIFO) and naked TCP port, which is fine for development. It routes commands to daemons using a file / inotifywait based message queue. Most code of interest about the queues is either in src/rpigo-authd.sh or in lib/queue.lib.

The various daemons mostly listen to administrative commands or perform some dedicated service function.


It's still really work in progress ;).
