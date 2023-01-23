#!/usr/bin/perl

use strict;
use warnings;
use Carp;

my $a;
$a=1/0;

print $a;
# We'll never get there
print "two\n";
