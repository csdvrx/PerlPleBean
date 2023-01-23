#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
 if (defined($ENV{PPB})) {
  STDOUT->autoflush(1);
  die ("done");
 } else {
  # otherwise define it
  $ENV{PPB} = "$$";
 }
 print STDERR "Main: $$ $ENV{PPB} starts as $^X " . join(',',@ARGV) . "\n"; # avoid autoflush issues by using stderr
}

END {
 print STDERR "Main: $$ ends\n";
}

print "forking\n";
my $pid = fork();
defined($pid) or die "$!";
if($pid == 0) {
    exec { $^X } ('perl', '--version');
    die "$!";
}
print "waiting for $pid\n";
waitpid($pid, 0);
print "$pid exited\n";


