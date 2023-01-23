#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::Multicast;
use Data::Dumper;

# Set up the socket
my $s = IO::Socket::Multicast->new(Proto=>'udp', LocalPort => 5353);

# Add a multicast group
$s->mcast_add('224.0.0.251') or die "Couldn't set group: $!\n";

for my $i (0..50){
    my $data;
    next unless $s->recv($data,1024);
    print Dumper($data);
}
