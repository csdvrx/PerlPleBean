#!/usr/bin/perl

use strict;
use warnings;
use Carp;

BEGIN {
 require Carp if defined $^S;
 Carp::confess("$?") if defined &Carp::confess;
}

my $a;
my $b;

# Block mode
eval {
 $a=1/0;
};
print STDOUT "Err: " . $? . "\n";
if ($@) {
 warn $@;
 print STDOUT "@ Err: " . $? . "\n";
}

eval {
 do ('./exit.pl');
 exit;
};
print STDOUT "Err: " . $? . "\n";
if ($@) {
 warn $@;
 print STDOUT "@ Err: " . $? . "\n";
}

END {
 print STDOUT "END block says $?\n";
}

