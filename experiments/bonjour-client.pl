#!/usr/bin/perl

use strict;
use warnings;

use Net::Bonjour;
# This high-level implementation depends on the request being to the given IP
# instead of just by multicast (necessary and sufficient condition for dns-sd -B)

# It also shows the A records are expected in the additional section
my $res = Net::Bonjour->new("http");

$res->discover;

foreach my $entry ( $res->entries ) {
   print "name= " . $entry->name . " , address=" . $entry->address . " , port=" . $entry->port . "\n";
   #use Data::Dumper;
   #print Dumper($entry);
}
