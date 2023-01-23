#!/usr/bin/perl

use strict;
use warnings;
use Carp;

#BEGIN {
# require Carp if defined $^S;
# Carp::confess("$?") if defined &Carp::confess;
#}

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

# String mode
eval "my \$a=1/0;";
print STDOUT "Err: " . $? . "\n";
if ($@) {
 warn $@;
 print STDOUT "@ Err: " . $? . "\n";
}

# Regular do
print "one\n";
do ('./helloworld.pl');

END {
 print STDOUT "END block says $?\n";
}

# We'll never get there
print "two\n";
