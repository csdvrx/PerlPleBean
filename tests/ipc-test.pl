#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
#use Symbol "gensym"; # if vivifications is used for STDERR problems like
#my $Pin  = new IO::Handle;
#$Pin->fdopen(10, "w");
#my $Pin  = new IO::Handle;
#$Pin->fdopen(11, "r");
#my $Pin  = new IO::Handle;
#$Pin->fdopen(12, "r");

# This is ipc-test.pl based on the begin.pl approach, so by construction it
# requires IPC::Run to be in main, past the "Chinese wall" of a BEGIN block
# because due to how fork() works, the child will never see past that wall
#
# This allows a simpler design with 2 simple scenarios around the wall:
#  - above the wall, the regular HTTP serving code only requesting IPC by
#    calling this same script but with arguments: what to run, output name
#  - under the wall, only the IPC::Run code actually doing the requested IPC
#    and bailing out early if it's not required (if there's no argument) as
#    will be the case when the server is first started

# Still, for safety, and for now deemed safer than return:
my $die_in_child=1;
# To separate main from child, keep the pid
my $pid="";
# Fork and exit (not returning error codes) or just fork
my $fork_and_exit=1;

my $cosmo;
# Could also use Config but simpler than 
# if ($Config{osname} =~ m/^cosmo/ || $Config{archname} =~ m/cosmo$/) {
if ($^O =~/cosmo/) {
 $cosmo=1;
}

#####################################################################
# main part: the regular PerlPleBean will be here, nothing can do IPC
#####################################################################
 # This is above the wall, so where the main HTTP server loop will go,
 # which can request IPC by calling itself, as just 2 cases are made:
 #  - this script called without any argument:
 #    - the child will start the http server
 #    - the main will then decide to do nothing and exit early
 #  - this script called with an argument:
 #    - the child will nodecide to do nothing and exit early, but even
 #  it has no other choice: this is  because the fork right below the
 #  beginning of the 'BEGIN' block will create a child that can't read past
 #  this wall, which prevents any child from doing any actual _run, and
 #  that's robust to any mistake thanks to how the BEGING block behaves

BEGIN {
 # fork: returns a value of 0 to the child process
 #       returns the process ID of the child process to the parent process
 if (0) {
  $pid = fork and exit;
 } else {
  $pid = fork;
 }
 unless ($pid == 0) {
  print STDOUT "Main: child pid is $pid\n";
 } else {
  print STDOUT "Child: (pid $pid)\n";
  if (scalar(@ARGV)>0) {
   # FIXME: This will be shown once when starting the http server, could also be removed
   print STDOUT ("Child: can't accept any arguments: reserved for the forking safety\n");
   exit(0);
  }
  # FIXME: not exactly, as in theory we could accept commandline arguments such
  # as flags, especially if starting with '-': this is because it's unlikely
  # there's a file with a name perfectly matching the name of that "-flag"
  print STDOUT "Placeholder for starting the HTTP server code\n";
  exit(0);
 } # unless pid
} # BEGIN

# Child can't see that part here thanks to the fork behavior decried in:
#  https://perldoc.perl.org/perlfork#CAVEATS-AND-LIMITATIONS
# The fork() emulation will not work entirely correctly when called from within
# a BEGIN block. The forked copy will run the contents of the BEGIN block, but
# will not continue parsing the source stream after the BEGIN block

#####################################################################
# protected part: the forking happens below this Chinese wall
#####################################################################

# WARNING: this is nice, however, this is not a lexical sub
# https://jacoby.github.io/perl/2018/08/29/use-perl-features-lexical_subs.html
#
# But what we really care is not exposing this by accident to the child so they
# can't fork or run other processes, so it doesn't matter much.

# This wouldn't make IPC::Run3 private (even if it was in the sub)
use IPC::Run3 qw(run3);

# However this sub should be private
my sub run {
 my $what=shift; # ARGV[0]: program to run
 my $save=shift; # ARGV[1]: save output name
 unless (defined($what)) {
  return(-1);
 } else {
  # The core issue with APPerl is $^X==$0, while we may want to run $^X $ARGV[0]
  # Even if the above construct will hide from child anything below the barrier,
  # which should guarantee this will not happen, let's still be safe and check
  # what we execute here isn't what is already running (a fork bomb otherwise!)
  my $fpart0=$0;
  # recode windows \ to unix / then keep the tail
  $fpart0=~s/\\/\//g;
  $fpart0=~s/.*\///g;
  my $fpartarg0=$what;
  $fpartarg0=~ s/\\/\//g;
  # keep the tail
  $fpartarg0=~s/.*\///g;
  # In cosmo mode, replace /bin by /zip/bin
  if ($cosmo) {
   print STDOUT "Cosmo mode detected";
   if ($what=~ m/^\/zip\//) {
    print STDOUT " but $what already with /zip prefix";
   } else {
    if ($what =~ m/^bin/) {
     print STDOUT " so prefixing $what with /zip\n";
     $what =~ s/bin/\/zip\/bin/;
    } else {
     print STDOUT " yet leaving $what as-is\n";
    }
   }
  }
  # Do the bare minimum to prevent abuse with non-printable ascii
  $what =~ s/[\0-\x1f].*$//g;
  $what =~ s/[';|"]//g;
  # FIXME: could also recode Windows \ and \\
  if ($fpart0 eq $fpartarg0) {
   die "Main: run: Tapping out to avoid forkbomb behavior of $^X due to $fpartarg0 matching $fpart0";
  } else {
   print STDOUT "Main: run: will try to run $^X $what instead of $^X /zip/bin/$fpart0\n";
  }
  my $run3;
  # FIXME: for now, make it 4x as much to be safe
  my $size=4096*16;
  #my $char="\0";
  my $char=' ';
  my $chld_in= $char x $size;
  my $chld_out=$char x $size;
  my $chld_err=$char x $size;
  # FIXME: could pass more arguments to the cmdline
  if (-f $what) {
   $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
  } else {
   print STDERR "Main: run: no such file: $what\n";
   exit(-1);
  } # if file what
  print STDOUT "FIXME: to be sent by HTTP post:\n";
  print STDOUT Dumper($chld_out);
  print STDOUT "Main: run: Done\n";
  return($run3);
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Main: run: 'nothing past this' ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub _fork

# we are certain this can only be seen by the parent
# but let's play it safe and do the equivalent of assert
if ($pid =~ m/^0$/) {
 print STDERR "Child: 'should never see this' ASSERTION BROKEN\n";
 die ("Tapping out as this should NOT have happened\n");
} else {
 # We are 100% positively certain we are in man
 unless (scalar(@ARGV)>0) {
  # No argument means this is a leftover of the initial start of PerlPleBean
  # which runs through child
  # FIXME: the main leftover from after the fork could also do other useful
  # things but not needed for for now, so make the Chinese wall also be
  # semantic:
  # what's before the wall is PerlPleBean HTTP server, what's after is for IPC
  # FIXME: This will be shown once when starting the server, could also be removed
  print STDOUT ("Main: exiting ASAP as forking is done and no run is required\n");
  exit(0)
 } else {
  # Prealloc to avoid any malloc issues, as we expect about 4kb of output
  print STDOUT "Main: on $^O running $^X as $0, attempting IPC run $ARGV[0]";
  if (defined($ARGV[1])) {
   print STDOUT " with output filename $ARGV[1]\n";
   $pid=run($ARGV[0], $ARGV[1]);
  } else {
   print STDOUT "\n";
   $pid=run($ARGV[0], "new.tsv"); # FIXME need a better name
  }
  print STDOUT "Main: done with $pid for $ARGV[0]\n";
  # Nothing left to do
  exit(0);
 } # scalar ARGV
} # if main pid
