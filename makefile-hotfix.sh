#!/bin/sh

# Due to last minute problems with the Makefile

cp com/sxs_perl.com com/perlplebean.com
cp -f src/Nameserver.pm cpan/lib/perl5/5.36.0/Net/DNS/Nameserver.pm
cp -f src/Nameserver.pm cpan/lib/perl5/Net/DNS/Nameserver.pm
cd cpan && zip -r ../com/perlplebean.com ./lib/perl5/5.36.0/ && zip -r ../perlplebean.com ./lib/perl5/5.36.0/ && cd ..
zip -r perlplebean.com lib/ bin/ cgi/ html/ tsv/

