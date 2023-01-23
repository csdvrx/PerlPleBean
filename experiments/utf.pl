#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

my $s="切腹";

print Dumper($s);

my $a;
for my $c (split //, $s) {
   $a .= sprintf("%%%02x", ord($c));
}

print Dumper($a);
print Dumper(uc($a));
