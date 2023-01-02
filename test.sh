#!/bin/sh
#CURRENT=$(ps ax|wc -l)
#NEW=$(($CURRENT+30))
#echo "Limiting process from the current $CURRENT to $NEW"
#echo "ulimit -u $NEW "
#ulimit -u $NEW
# FIXME: test.sh: 6: ulimit: Illegal option -u
# Still, this can catch the forkbomb in both cases
./repack.sh ipc-test.pl && (\
 ./perlplebean.com && \
 ./perlplebean.com bin/hello.pl ; \
 ./perlplebean.com && \
 ./perlplebean.com bin/helloworld.pl)
