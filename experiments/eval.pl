#!/usr/bin/perl

use strict;
use warnings;
use Eval::Safe;
use Carp;
use Data::Dumper;

print Dumper (@ARGV);
eval {
 BEGIN { *CORE::GLOBAL::exit = sub (;$) { print STDERR "EXIT_CALLED($_[0])\n"; exit($_[0]); } } # Make exit() do nothing
 my $eval = Eval::Safe->new(safe=>0, strict=>1, warnings=>1);
 local @ARGV;
 $ARGV[0]="one";
 $ARGV[1]="two";
 $eval->do ('./helloworld.pl');
 $eval->do ('./gobble.pl');
};
print STDOUT "Err: " . $? . "\n";
if ($@) {
 warn $@;
 print STDOUT "@ Err: " . $? . "\n";
}

eval {
 #BEGIN { *CORE::GLOBAL::exit = sub (;$) { print STDERR "EXIT_CALLED($_[0])\n" } } # Make exit() do nothing
 do ('./helloworld.pl aa');
 #do ('./hello.pl');
};
print STDOUT "Err: " . $? . "\n";
if ($@) {
 warn $@;
 print STDOUT "@ Err: " . $? . "\n";
}

#END {
# print STDOUT "END block says $?\n";
#}

