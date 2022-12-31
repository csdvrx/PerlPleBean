#!/usr/bin/perl
## Modern perl
use v5.14;                      # for /r match+assign on regexp and ~~ smartmatch
use strict;
use warnings;
use open qw(:std);              # should use unicode, but (:std :utf8) gives mojibake

## Minimalistic set of dependancies: must not come from CPAN for portability
use Data::Dumper;               # for cheap debug, always present by default

print STDOUT "Hello $^X $0 \n";

foreach my $k (sort keys(%ENV)) {
  if ($k =~ m/^HTTP/ or $k =~ m/^URI/) {
  #unless ($k =~ m/^LS_COLORS|^PS/) { # ad-hoc but LS_COLORS and my PS0 PS1 are just too long..
   print STDOUT "Key $k Value $ENV{$k}\n";
  }
}
