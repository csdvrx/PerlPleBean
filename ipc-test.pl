#!/usr/bin/perl
use strict;
use warnings;
use Config; # For checking the OS, because $OSNAME doesn't work in APPerl
use Data::Dumper;
# IPC::Run3 is a glorified system() using temp files
use IPC::Run3::Simple;
use IPC::Run3 qw(run3);
# The real deal
use IPC::Run qw(timeout);
# To vivify
use Symbol "gensym";

my $debug=0;

# Will get some input data from HTTP POST, and return it after running it through a perl script
my $chld="/tmp/test.pl"; # created below
my $testinput="line 1 just lf\nline 2 just lf\nline3 has crlf\r\nline 4 just lf\n";

# And this will check if the output is in the right place
sub check {
 my $what=shift;
 my $normal=shift;
 my $ok=0;
 my $nbr=0;
 foreach my $line (split("\n",$what)) {
  $nbr++;
  if ($debug >0) {
  print STDOUT "Checking $line for ok=$normal\n";
  }
  if ($line =~m/$normal/) {
   $ok++;
  }
 }
 my $conclusion="$ok of $nbr";
 return ($conclusion);
}

my $cosmo;
if ($Config{osname} =~ m/^cosmo/ || $Config{archname} =~ m/cosmo$/) {
  $cosmo=1;
} else {
  $cosmo=0;
}

# perl doesn't release memory to the system to reallocate as needed
# Leverage that behavior: prealloc 4k to simulate that

print STDOUT "Doing a pre malloc\n";

my $size=4096;
#my $char="\0";
my $char=' ';
my $chld_in= $char x $size;
my $chld_out=$char x $size;
my $chld_err=$char x $size;

# TODO: should check each one of them, not just a canary
my $prealloc_check= length(Dumper($chld_out))-(length('$VAR1 = " "')+1);
unless ($size==$prealloc_check){
 print STDERR "prealloc size differs for chld_out\n";
}

# Accounting of true and false positives and negatives
my @normal_truepos;
my @normal_fakepos;
my @error_fakepos;
my @error_truepos;

$chld_in=$testinput;

my $lines=scalar(split("\n",$chld_in));
print STDOUT "Now starting tests with stdin<<EOF\n";
print STDOUT $chld_in;
print STDOUT "EOF containing $lines lines sent to STDOUT and STDERR\n";
print STDOUT "along with 1 line correctly sent to STDOUT and STDERR\n";
print STDOUT "then checking they all arrive at the right places\n";
open my $FH_TEST, '>', $chld;
print {$FH_TEST} <<'EOF';
print STDOUT "Normal\n";
print STDERR "Error\n";
unless (-t STDIN) {
 while (<>){
  print STDOUT "Normal: $_";
  print STDERR "Error : $_";
 }
}
EOF
close $FH_TEST;

if (1) {
 print STDOUT "\nFirst trying with no input run3 simple";
 my $run3s=IPC::Run3::Simple::run3 (["$^X", "$chld"], undef, \$chld_out, \$chld_err), timeout (2) or print STDERR ("run3 simple error $!");
 print STDOUT "...no input run3 simple results: $run3s\n";
 if ($debug>0) {
  print STDOUT "stdout:\n";
  print STDOUT Dumper $chld_out;
  print STDOUT "stderr:\n";
  print STDOUT Dumper $chld_err;
 }
 print STDOUT "GOOD: Normal on STDOUT in " . check($chld_out, "Normal") . "\n";
 print STDOUT "\tBAD: Normal found on STDERR in " . check($chld_err, "Normal") . "\n";
 print STDOUT "GOOD: Error on STDERR in " . check($chld_err, "Error") . "\n";
 print STDOUT "\tBAD: Error found on STDOUT in " . check($chld_out, "Error") . "\n";
}

# first, IPC::Run3::Simple: simply run3 with stdin left to undef
if (1) {
 print STDOUT "\nNow trying run3 simple... ";
 my $run3s=IPC::Run3::Simple::run3 (["$^X", "$chld"], \$chld_in, \$chld_out, \$chld_err), timeout (2) or print STDERR ("run3 simple error $!");

 print STDOUT "...run3 simple results: $run3s\n";
 if ($debug>0) {
  print STDOUT "stdin:\n";
  print STDOUT Dumper $chld_in;
  print STDOUT "stdout:\n";
  print STDOUT Dumper $chld_out;
  print STDOUT "stderr:\n";
  print STDOUT Dumper $chld_err;
 }
 print STDOUT "GOOD: Normal on STDOUT in " . check($chld_out, "Normal") . "\n";
 print STDOUT "\tBAD: Normal found on STDERR in " . check($chld_err, "Normal") . "\n";
 print STDOUT "GOOD: Error on STDERR in " . check($chld_err, "Error") . "\n";
 print STDOUT "\tBAD: Error found on STDOUT in " . check($chld_out, "Error") . "\n";
}

# Then IPC::Run3
if (1) {
 print STDOUT "\nNow trying run3 with timeout 2... ";
 my $run3=IPC::Run3::run3 (["$^X", "$chld"], \$chld_in, \$chld_out, \$chld_err), timeout( 2) or print STDERR ("run3 error $!");

 print STDOUT "...run3 results: $run3\n";
 if ($debug>0) {
  print STDOUT "stdin:\n";
  print STDOUT Dumper $chld_in;
  print STDOUT "stdout:\n";
  print STDOUT Dumper $chld_out;
  print STDOUT "stderr:\n";
  print STDOUT Dumper $chld_err;
 }
 print STDOUT "GOOD: Normal on STDOUT in " . check($chld_out, "Normal") . "\n";
 print STDOUT "\tBAD: Normal found on STDERR in " . check($chld_err, "Normal") . "\n";
 print STDOUT "GOOD: Error on STDERR in " . check($chld_err, "Error") . "\n";
 print STDOUT "\tBAD: Error found on STDOUT in " . check($chld_out, "Error") . "\n";
}

# finally IPC::Run
if (1) {
 print STDOUT "\nNow trying run with timeout 2... ";
 my $run=IPC::Run::run (["$^X", "$chld"], \$chld_in, \$chld_out, \$chld_err), timeout( 2 ) or print STDERR ("run error $!");
 print STDOUT "...run results: $run\n";
 if ($debug>0) {
  print STDOUT "stdin:\n";
  print STDOUT Dumper $chld_in;
  print STDOUT "stdout:\n";
  print STDOUT Dumper $chld_out;
  print STDOUT "stderr:\n";
  print STDOUT Dumper $chld_err;
 }
 print STDOUT "GOOD: Normal on STDOUT in " . check($chld_out, "Normal") . "\n";
 print STDOUT "\tBAD: Normal found on STDERR in " . check($chld_err, "Normal") . "\n";
 print STDOUT "GOOD: Error on STDERR in " . check($chld_err, "Error") . "\n";
 print STDOUT "\tBAD: Error found on STDOUT in " . check($chld_out, "Error") . "\n";
}

# FIXME also try IO handles and gensym to vivify them
#   my $Pin  = new IO::Handle;
#   $Pin->fdopen(10, "w");
#   my $Pin  = new IO::Handle;
#   $Pin->fdopen(11, "r");
#   my $Pin  = new IO::Handle;
#   $Pin->fdopen(12, "r");

#my ($gs_in, $gs_out, $gs_err)=map gensym, 1..3;
print STDOUT "\nDone with the tests";
