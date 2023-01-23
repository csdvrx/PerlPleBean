#!/usr/bin/perl
## Modern perl
use v5.14;                      # for /r match+assign on regexp and ~~ smartmatch
use strict;
use warnings;
use open qw(:std);              # should use unicode, but (:std :utf8) gives mojibake
use Data::Dumper;

print STDOUT "$^X $0 " . join(" ", @ARGV) . "\n";
print STDOUT "Hello\n";
print STDOUT "World \n";
print STDOUT Dumper(@ARGV);
print STDERR "No error but I will exit 4\n";

#foreach my $k (sort keys(%ENV)) {
# # if ($k =~ m/^HTTP/ or $k =~ m/^URI/) {
#  unless ($k =~ m/^LS_COLORS|^PS/) { # ad-hoc but LS_COLORS and my PS0 PS1 are just too long..
#   print STDOUT "Key $k Value $ENV{$k}\n";
#  }
#}
exit(4);
