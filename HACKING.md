
Development notes are in [my Evernote](http://www.evernote.com/l/AIBBnV16K9ZF9LcGfxjjBoMoooO77pWrTBg/).

Code is structured like this:

    - config
        + Default configuation files.
    - lib
        + Library code shared among daemons.
    - share
        + Data files.
    - src
        + Source code for the various daemons.

The place to start reading is src/rpigo-init.sh.

Determining commands is done by src/rpigo-authd.sh. The only backend right now is a FIFO, which is fine for development. It routes commands to daemons using a file / inotifywait based message queue. Most code of interest about the queues is either there or in lib/queue.lib.

The various daemons mostly listen to administrative commands or perform some dedicated service function.


It's still really work in progress ;).
