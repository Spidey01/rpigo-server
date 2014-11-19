#!/bin/sh
$(dirname $0)/stop-all.sh ; pkill inotifywait ; rm /tmp/rpigo.queue/*
