#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
#use Symbol "gensym";
# if vivifications is used for STDERR problems like
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
#  - before the wall, the regular HTTP serving code only requesting IPC by
#    calling this same script but with arguments: what to run, output name
#  - after the wall, only the IPC::Run code actually doing the requested IPC
#    and bailing out early if it's not required (if there's no argument) as
#    will be the case when the server is first started

# To separate main from child, keep the pid
my $pid;
# To prevent a fork bomb, it will used behind the chinese wall:
#  refuse further forks by checking before IPC::Run if it hasn't changed

# Detect if we're in cosmo
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
 $pid = fork;
 # When fork succeeds, the program splits into two:
 # fork returns:
 #  - undef on failure
 #  - a value on success, to know who we we are as the program splits into two
 #    - 0 means we are the child process: will die if the parent dies unless setsid
 #    - any other value means we are the parent: it's the process ID of the child
 unless (defined ($pid)) {
  # Refuse to go further if fork failed
  die("Fork failed while we need fork \n");
  # FIXME: could just run the normal IPC-less HTTP server like when $pid==0 below
 }
 unless ($pid == 0) {
  #####################################################################
  # Parent
  #####################################################################
  # FIXME: on WSL2, could use the fact this pid is abnormally low and never changes
  print STDOUT "Parent: child pid is $pid\n";
  # Don't assume we are protected from zombies by $SIG{CHLD}='IGNORE';
  #waitpid($pid,0);
  # Alternative:
  use POSIX 'WNOHANG';
  $SIG{CHLD} = sub { while( waitpid(-1,WNOHANG)>0 ) {  } };
  print STDOUT "Parent: child pid $pid finished\n";
 } else {
  #####################################################################
  # Child
  #####################################################################
  print STDOUT "Child: ";
  # FIXME: should things opened by the parent (STDIN, STDOUT...) be closed?
  # When the child quits, it report termination to the parent.
  # If the parent has no wait() to collect it, the child is confused and
  # becomes a zombie: can't be killed, will die only when the parent dies
  if (scalar(@ARGV)>0) {
   print STDOUT ("exiting: because arguments to preserve forking safety\n");
   exit(0);
  }
  # FIXME: not exactly, as in theory we could accept commandline arguments such
  # as flags, especially if starting with '-': this is because it's unlikely
  # there's a file with a name perfectly matching the name of that "-flag"
  print STDOUT "placeholder for starting the HTTP server code\n";
  exit(0);
 } # unless pid
} # BEGIN

# Child can't see that part here thanks to the fork behavior decried in:
#  https://perldoc.perl.org/perlfork#CAVEATS-AND-LIMITATIONS
# The fork() emulation will not work entirely correctly when called from within
# a BEGIN block. The forked copy will run the contents of the BEGIN block, but
# will not continue parsing the source stream after the BEGIN block
if (defined($ARGV[2])) {
 if ($ARGV[2] =~ m/FINAL/) {
  die ("Refusing to pass the Chinese wall as it should have been the final run\n");
 }
}

#####################################################################
# protected part: the forking happens below this Chinese wall
#####################################################################

if ($pid=~ m/^0$/) {
 print STDERR "Child: should never see this: ASSERTION BROKEN\n";
 die ("Tapping out as this should NOT have happened\n");
}

print STDOUT "Parent: on $^O running $^X as $0\n";
print STDOUT "Parent: passed the Chinese wall, left child behind: $pid\n";

# WARNING: this is nice, however, this is not a lexical sub
# https://jacoby.github.io/perl/2018/08/29/use-perl-features-lexical_subs.html
#
# But what we really care is not exposing this by accident to the child so they
# can't fork or run other processes, so it doesn't matter much.

# This wouldn't make IPC::Run3 private (even if it was in the sub)
use IPC::Run3 qw(run3);

# However this sub should be private
my sub run {
 my $what=shift; # @_[0]: program to run
 my $save=shift; # @_[1]: save output name
 my $cpid=shift; # @_[2]: pre-existing child pid
 my $defuse; # if set, will specify what's executed should not even try to IPC again
 # FIXME: should then be followed by any other flag
 unless (defined($cpid)) {
  die "Parent: run: Tapping out to avoid forkbomb behavior of $^X due to unknown previous child pid $pid";
 }
 unless (defined($pid)) {
  die "Parent: run: Tapping out to avoid forkbomb behavior of $^X due to unknown current child pid $pid";
 }
 if ($cpid eq $pid) {
  # the pid hasn't changed, which means we could enter in a recursive behavior (fork-bomb)
  # prevent that by saying this run is final
  print STDERR "Parent: run: RISK OF FORKBOMB $^X due to previous child pid $cpid matching current child pid $pid\n";
  # Can we mitigate that?
  $defuse=1;
 }
 unless (defined($what)) {
  print STDERR "Parent: run: what to run undefined\n";
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
   die "Parent: run: Tapping out to avoid forkbomb behavior of $^X due to $fpartarg0 matching $fpart0";
  } else {
   print STDOUT "Parent: run: $^X with $what instead of $fpart0 from $0\n";
  }
  my $run3;
  # Perl reuses allocated memory whenever possible
  # cf https://www.oreilly.com/library/view/practical-mod_perl/0596002270/ch10.html
  # So prealloc to avoid any malloc issues, as we expect about 4kb of output
  my $size=4096;
  #my $char="\0";
  my $char=' ';
  my $chld_in= $char x $size;
  my $chld_out=$char x $size;
  my $chld_err=$char x $size;
  if (-f $what) {
  # FIXME: could pass more arguments after the pid
   unless ($defuse) {
    print STDOUT "Parent: run: starting $^X $ARGV[0] $pid\n";
    $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]", "$pid"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
   } else {
    print STDOUT "Parent: run: CAUTION: $^X $ARGV[0] FINAL\n";
    $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]", "FINAL"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
   }
  } else {
   print STDERR "Parent: run: no such file: $what\n";
   exit(-1); # FIXME: would kill the http server we're not inside a IPC::Run
  } # if file what
  # FIXME: to be sent by HTTP post
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  print STDERR "Parent: run: received $chld_out\n";
  print STDOUT "Parent: run: exiting with $run3\n";
  # return($run3);
  # FIXME: maybe better to exit
  # so exit with the same value
  exit($run3);
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Parent: run: nothing past this: ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub _fork

# we are certain this can only be seen by the parent
# but let's play it safe and do the equivalent of assert
if ($pid=~ m/^0$/) {
 print STDERR "Child: should never see this: ASSERTION BROKEN\n";
 die ("Tapping out as this should NOT have happened\n");
} else {
 # We are 100% positively certain we are in man
 unless (scalar(@ARGV)>0) {
  # No argument means this parent is a leftover of the initial start
  # of PerlPleBean which runs through child
  # FIXME: the main leftover from after the fork could also do other useful
  # things not needed for now, so make the Chinese wall also be semantic:
  # what's before the wall is PerlPleBean HTTP server, what's after is for IPC
  print STDOUT ("Parent: exiting ASAP as forking is done and no run is required\n");
  exit(0)
 } else {
  #if (defined($ARGV[2])) {
  # print STDERR "got argv2 $ARGV[2]\n";
  # die;
  #}
  print STDOUT "Parent: requesting run of $^X $ARGV[0] $pid";
  my $return;
  if (defined($ARGV[1])) {
   print STDOUT " with output filename $ARGV[1]\n";
   # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
   $return=run($ARGV[0], $ARGV[1], $pid);
  } else {
   print STDOUT "\n";
   $return=run($ARGV[0], "new.tsv", $pid); # FIXME need a better name if doing http post
  }
  # FIXME: this would forces success, instead stop within _sub uses the same return code
  # So this will never be shown
  print STDOUT "Parent: retuned $return for $ARGV[0]\n";
  # And this will never be used
  exit(0);
 } # scalar ARGV
} # if main pid
