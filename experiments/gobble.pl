#!/usr/bin/perl
## Modern perl
use v5.14;                      # for /r match+assign on regexp and ~~ smartmatch
use strict;
use warnings;
use open qw(:std);              # should use unicode, but (:std :utf8) gives mojibake

print STDOUT "Hello $^X $0 \n";

my $ln=0;
my $a=0;
my $b=0;
while (<>) {
 $ln++;
 if ($_ =~ m/A/) {
  $a++;
 }
 if ($_ =~ m/B/) {
  $b++;
 }
}

print STDOUT "Read $ln lines\n";
print STDOUT "Found $a As and $b Bs\n";
exit(3);
