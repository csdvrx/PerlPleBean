#!/usr/bin/perl

use strict;
use warnings;

our $ignore_exit;
our $exit_ignored;
BEGIN {
 *CORE::GLOBAL::exit = sub(;$) {
  if ($ignore_exit) {
   # Conditional to avoid error at startup
    # Save the value
    $exit_ignored=$_[0];
   # And say what happened
   print STDERR "IGNORED_EXIT($_[0])\n";
  } else { # if ignore_exit
   CORE::exit( $_[0] // 0 )
  } # if ignore_exit
  no warnings qw( exiting );
  # use the last defined behavior
  last EXIT_OVERRIDE;
 }; # sub
} # BEGIN block 2

EXIT_OVERRIDE: {
   local $ignore_exit=1;
   eval {
    print "not calling exit\n";
    #exit(1);
    };
}
if ($exit_ignored) {
   print "Exit called\n";
} elsif ( $@ ) {
   print "Exception: $@\n";
} else {
   print "Normal return\n";
}
# Then reset the detector
$exit_ignored=undef;

EXIT_OVERRIDE: {
   local $ignore_exit=1;
   eval {
    print "calling exit -3\n";
    exit(-3);
    };
}
if ($exit_ignored) {
   print "Exit called\n";
} elsif ( $@ ) {
   print "Exception: $@\n";
} else {
   print "Normal return\n";
}
# Then reset the detector
$exit_ignored=undef;

EXIT_OVERRIDE: {
   local $ignore_exit=0;
   eval {
    print "calling exit 2 with no ignore\n";
    exit(2);
    };
}
if ($exit_ignored) {
   print "Exit called\n";
} elsif ( $@ ) {
   print "Exception: $@\n";
} else {
   print "Normal return\n";
}
# Then reset the detector
$exit_ignored=undef;

print "This will never be printed due to the lack of override\n";
