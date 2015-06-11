alias L="cd /var/log/rpigo"
alias S="cd /home/pi/rpigo-server/"
alias Q="cd /var/spool/rpigo/queue"
C() { # yeah, I'm really functional :P.
    (S && sudo ./scripts/send.sh -r $*)
}
