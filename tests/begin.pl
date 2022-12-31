#!/usr/bin/perl
use strict;
use warnings;
use IPC::Run3 qw(run3);
use Data::Dumper;

# This is begin.pl, requiring runs_in_main by construction
my $run_in_main=1;
my $die_in_main=1;
my $run_in_child=0;
my $die_in_child=1;
my $fork_and_exit=1;


# With fork.pl, need fork_and_exit=0 if we want to see both the child and main
# with begin.pl, both are fine
# with fork.pl, fork_and_exit matters more than die_in_main: both need to be 0 to do main fork +things after fork
# With begin.pl, fork_and_exit guarantees not running in child
#
# FIXME: for cgi, couldn't it just be check env?
#foreach my $k (sort keys(%ENV)) {
#  print STDOUT "Key $k Value $ENV{$k}\n";
#}

if (scalar(@ARGV)>0) {
 print STDOUT "On $^O $^X as $0 called with argument $ARGV[0]\n";
} else {
 print STDOUT "On $^O $^X as $0 called without argument\n";
}

my $size=4096;
#my $char="\0";
my $char=' ';
my $chld_in= $char x $size;
my $chld_out=$char x $size;
my $chld_err=$char x $size;

if (scalar(@ARGV)>0) {
 print STDOUT "Will try to start $^X $0 with goal $ARGV[0]\n";
}

my $pid="";
BEGIN {
 print STDOUT "Inside a BEGIN block\n";
 if ($fork_and_exit) {
  $pid = fork and exit;
 } else {
  $pid = fork;
 }
 if ($pid == 0) {
  print STDOUT "Child\n";
  if ($run_in_child) {
   if (scalar(@ARGV)>0) {
    my $fpart0=$0;
    # recode windows \ to unix / then keep the tail
    $fpart0=~s/\\/\//g;
    $fpart0=~s/.*\///g;
    my $fpartarg0=$ARGV[0];
    $fpartarg0=~ s/\\/\//g;
    # keep the tail
    $fpartarg0=~s/.*\///g;
    if ($fpart0 eq $fpartarg0) {
     die "Avoiding forkbomb behavior of $^X due to $fpartarg0 matching $fpart0";
    }
    print STDOUT "Running $ARGV[0]\n";
    my $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
    print STDOUT Dumper($chld_out);
    print STDOUT "Done\n";
   } # if argv
   if ($die_in_child) {
    die;
   }
  } # if run_in_child
 } else {
  print STDOUT "Main\n";
 }
} # BEGIN

# Here, leverage the fork behavior decried on cpan:
# The fork() emulation will not work entirely correctly when called from within
# a BEGIN block. The forked copy will run the contents of the BEGIN block, but
# will not continue parsing the source stream after the BEGIN block

# Child can't see that part here
if ($run_in_main) {
 if (scalar(@ARGV)>0) {
  my $fpart0=$0;
  # recode windows \ to unix / then keep the tail
  $fpart0=~s/\\/\//g;
  $fpart0=~s/.*\///g;
  my $fpartarg0=$ARGV[0];
  $fpartarg0=~ s/\\/\//g;
  # keep the tail
  $fpartarg0=~s/.*\///g;
  if ($fpart0 eq $fpartarg0) {
   die "Avoiding forkbomb behavior of $^X due to $fpartarg0 matching $fpart0";
  }
  print STDOUT "Running $ARGV[0]\n";
  my $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
  print STDOUT Dumper($chld_out);
  print STDOUT "Done\n";
 } # if argv
 if ($die_in_main) {
  die;
 }
} # if run_in_main
print STDOUT "Stop $pid\n";
