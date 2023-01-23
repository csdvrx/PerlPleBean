#!/usr/bin/perl

use strict;
use warnings;

our $override_exit = 0;
BEGIN {
   *CORE::GLOBAL::exit = sub(;$) {
      CORE::exit( $_[0] // 0 ) if !$override_exit;

      no warnings qw( exiting );
      last EXIT_OVERRIDE;
   };
}

my $exit_called = 1;
EXIT_OVERRIDE: {
   local $override_exit = 1;
   eval {
    print "not calling exit\n";
    #exit(1);
    };
   $exit_called = 0;
}
if ( $exit_called ) {
   print "Exit called\n";
} elsif ( $@ ) {
   print "Exception: $@\n";
} else {
   print "Normal return\n";
}

$exit_called = 1;
EXIT_OVERRIDE: {
   local $override_exit = 1;
   eval {
    print "calling exit with override\n";
    exit(1);
    };
   $exit_called = 0;
}
if ( $exit_called ) {
   print "Exit called\n";
} elsif ( $@ ) {
   print "Exception: $@\n";
} else {
   print "Normal return\n";
}

$exit_called=1;
EXIT_OVERRIDE: {
   local $override_exit = 0;
   eval {
    print "calling exit without override\n";
    exit(1);
    };
   $exit_called = 0;
}
if ( $exit_called ) {
   print "Exit called\n";
} elsif ( $@ ) {
   print "Exception: $@\n";
} else {
   print "Normal return\n";
}

print "This will never be printed due to the lack of override\n";
