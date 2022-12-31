#!/bin/sh

if [ $# -eq 0 ]
  then
    echo "No arguments supplied!\n"
    echo "Usage:\n\t$0 filename\n\nWill then use filename as zip/bin/perlplebean in ./perlplebean.com\n"
    exit 0
fi

echo "Packing $1 in perlplebean.com to replace bin/perlplebean"

# small perl, but would need tweaks from cpan/perl5/lib/perl5/ to lib/perl5/5.36.0/
# to put the cpan stuff in the right place
# Ex: cpan/perl5/lib/perl5/IPC/Run3/ProfLogReader.pm
# =>      lib/perl5/5.36.0/IPC/Run3/ProfLogReader.pm
# And I don't want to bother (yet)
#ls perlplebean.com || ( echo "recreating with smallperl" && cp ../keep/perl.com perlplebean.com
# && cd ../cpan/perl5 && zip ../../tests/ipc-test.com -r lib/ && cd ../../tests)

# So use the regular binary with everything in the right place
ls perlplebean.com || ( echo "No ./perlplebean.com, taking it from ../"; cp ../perlplebean.com ./perlplebean.com || exit 0)

cp $1 bin/perlplebean
zip perlplebean.com -r bin/perlplebean
# show the result
ls -la perlplebean.com
# get the asset size
INSIZE=$(unzip -lv perlplebean.com |grep bin/perlplebean$|sed -e 's/^[ \t]*//g' -e 's/ .*//g')
OUTSIZE=$(stat -c %s $1)
echo "contains $1 of size $INSIZE:"
unzip -lv perlplebean.com|grep " bin/" |grep pl$
if [ "$INSIZE" = "$OUTSIZE" ]; then
 echo "which matches $1 of size $OUTSIZE:"
 ls -la $1
 # OK
 exit 0
else
 echo "WHICH DOESN'T MATCHES???"
 ls -la $1
 # KO
 exit 1
fi
