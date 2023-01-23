#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

BEGIN {
 if (defined($ENV{PPB})) {
  unless (0+"$$" == 0+"$ENV{PPB}") {
   die ("Fork risk as $ENV{PPB} not $$\n");
  }
 }
}

# This is ipc-test.pl based on the begin.pl approach, so by construction it
# requires the parent to do it, past the "Chinese wall" of a BEGIN block
# inside which fork() happens: then the child will never see past that wall
#
# This allows a simpler design with 2 simple scenarios around the wall:
#  - before the wall, the regular HTTP serving code only requesting IPC by
#    calling this same script but with arguments: what to run, output name
#  - after the wall, only the IPC::Run code actually doing the requested IPC
#    and bailing out early if it's not required (if there's no argument) as
#    will be the case when the server is first started


# The main drawback of evalsafedo is that any exit within the code
# that's executes gets us... nothing in stdout

#####################################################################
# APPerl no-forkbomb ~= like POSIX named semaphore but %ENV instead
#####################################################################

# Simply use a BEGIN block to detect the forking, and instead do or eval
BEGIN {
 unless (defined($ENV{PPB})) {
  # define it to the current pid if never defined
  $ENV{PPB} = "$$";
 } else { # unless defined $ENV{PPB}
  # we're already running...
  if (defined($ENV{PPBIPC})) {
   # ... and we want an IPC
   my $file = "./$ENV{PPBIPC}";
   my $return;
   unless ($return = do $file) {
    print STDOUT "Cant parse $file: $@" if $@;
    print STDOUT "Cant do $file: $!"    unless defined $return;
    print STDOUT "Cant run $file"       unless $return;
   } else { # unless defined $ENV{PPBIPC}
    print STDERR "returnwas $return\n";
    die ("WTF $?");
   } # unless do
  } else { # if defined $ENV{PPBIPC}
    die ("Nothing to do");
  } # if defined $ENV{PPBIPC}
 } # unless defined $ENV{PPB}
} # BEGIN
END {
 # every variable will have been undef so use $$
 print STDERR "Main: $$ ends returned $?\n";
} # END

BEGIN{
 print "$$ im the parent\n";
}

# We could prefix things with that to detect other forkbomb risks
my $mainpid=$$;

# To separate main from child, keep the pid from fork
my $pid;

# To prevent a fork bomb, it will used behind the chinese wall:
#  refuse further forks by checking before IPC::Run if it hasn't changed

# Detect if we're in cosmo
my $cosmo;

# Could also use Config but simpler:
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
 # This is a special construct: fork within a BEGIN block
 $pid = fork;
 # As usual, when fork succeeds, the program splits into two:
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
  # FIXME: why on WSL2 is the pid abnormally low + never changes?
  # and why is it not matching what's reported by $$ in the END block?
  print STDOUT "Parent:$$: child pid is $pid\n";
  # Don't assume we are protected from zombies by $SIG{CHLD}='IGNORE';
  #waitpid($pid,0);
  # Alternative:
  use POSIX 'WNOHANG';
  $SIG{CHLD} = sub { while( waitpid(-1,WNOHANG)>0 ) {  } };
  print STDOUT "Parent:$$: child pid $pid finished\n";
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
   # FIXME: not exactly, as in theory we could accept commandline arguments such
   # as flags, especially if starting with '-': this is because it's unlikely
   # there's a file with a name perfectly matching the name of that "-flag"
   exit(0);
  }
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
# protected part: the IPC run or eval happens below this Chinese wall
#####################################################################

if ($pid=~ m/^0$/) {
 print STDERR "Child: should never see this: ASSERTION BROKEN\n";
 die ("Tapping out as this should NOT have happened\n");
}

print STDOUT "Parent: on $^O running $^X as $0\n";
print STDOUT "Parent: passed the Chinese wall, left child behind: $pid\n";

# WARNING: this fork within BEGIN is nice, however, this is not a lexical sub
# https://jacoby.github.io/perl/2018/08/29/use-perl-features-lexical_subs.html
#
# Having "use" here doesn't make any of these private (even if it was in the sub)
use Eval::Safe;
# However, this sub should be private: we want to avoid exposing it by accident
# to the child so they can't fork or run other processes, so it's good enough!
my sub evalsafedo {
 my $what=shift; # @_[0]: program to eval
 my $save=shift; # @_[1]: save output name
 my $ppid=shift; # @_[2]: pre-existing parent pid
 my $defuse; # if set, will specify what's executed should not even try to IPC again
 my $retval; # if we get $? save it here and use it as a return value
 # FIXME: should then be followed by any other flag
 unless (defined($ppid)) {
  die "Parent: evalsafedo: Tapping out to avoid forkbomb behavior of $^X due to unknown parent pid $pid:$$";
 }
 unless ($ppid eq $$) {
  # the pid has changed, which means we could enter in a recursive behavior (fork-bomb)
  # prevent that by saying this run is final
  print STDERR "Parent: evalsafedo: RISK OF FORKBOMB $^X due to parent pid $ppid NOT matching current parent pid $$\n";
  # Can we mitigate that?
  $defuse=1;
 }
 unless (defined($what)) {
  print STDERR "Parent: evalsafedo: what to eval undefined\n";
  return(-1);
 } else {
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
  # Do the bare minimum to prevent abuse with non-printable ascii and separators
  $what =~ s/[\0-\x1f].*$//g;
  $what =~ s/[';|"]//g;
  # FIXME: could also recode Windows \ and \\
  # Perl reuses allocated memory whenever possible
  # cf https://www.oreilly.com/library/view/practical-mod_perl/0596002270/ch10.html
  # So prealloc to avoid any malloc issues, as we expect about 4kb of output
  my $size=4096;
  #my $char="\0";
  my $char=' ';
  my $chld_in= $char x $size;
  my $chld_out=$char x $size;
  my $chld_err=$char x $size;
  my $content;
  unless (-f $what) {
   print STDERR "Parent: evalsafedo: no such file: $what\n";
   exit(-1); # FIXME: would kill the child, so the http server if we're not in a fork
  } # if file what
  print STDOUT "Parent: evalsafedo $what\n";
  use Safe;
  my $eval = Eval::Safe->new(safe=>0); # slower and not working well anyway
  my $ret;
  {
    open local *STDOUT, '>', \$chld_out or die "Cant redirect stdout: $!";
    open local *STDERR, '>', \$chld_err or die "Cant redirect stderr: $!";
    # STDERR is line buffered.
    # if we must have STDOUT line buffered instead of block buffered
    STDOUT->autoflush(1);
     select(STDOUT); $|=1; # doesn't help
    #$eval->do ($what);
    $ret = $eval->do ($what);
    close (STDOUT);
    close (STDERR);
  }
  print STDOUT "Parent: evalsafedo: $ret got >$chld_out< and >$chld_err<\n";
# Every end block is execute when exiting, so can't use that just for evalsafedo
END {
 print "Ending evalnsave $?\n";
}
   # FIXME: use retval
  print STDOUT "Parent: evalsafedo: returned with $ret $?\n";
  #FIXME: to be sent by HTTP post to as the http server will run in child
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  $chld_err=~s/\x0D$//g;
  $chld_err=~s/\x0A$//g;
  print STDERR "Parent: evalsafedo: received STDOUT=$chld_out\n";
  print STDERR "Parent: evalsafedo: received STDERR=$chld_err\n";
  # FIXME: maybe better to exit
  #exit($retval);
  # FIXME: problem: no more run3, so just exit
  return($retval); # FIXME: due to eval safe issue, this is implied: won't return if it dies lol
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Parent: evalsafedo: nothing past this: ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub evalsafedo

# we are certain this can only be seen by the parent
# but let's play it safe and do the equivalent of assert
if ($pid=~ m/^0$/) {
 print STDERR "Child: should never see this: ASSERTION BROKEN\n";
 die ("Tapping out as this should NOT have happened\n");
} else {
 # We are 100% positively certain we are in main
 unless (scalar(@ARGV)>0) {
  # No argument means this parent is a leftover of the initial start
  # of PerlPleBean which runs through child
  # FIXME: the main leftover from after the fork could also do other useful
  # things not needed for now, so make the Chinese wall also be semantic:
  # what's before the wall is PerlPleBean HTTP server, what's after is for IPC
  print STDOUT ("Parent: exiting ASAP as forking is done and no eval is required\n");
  exit(0)
 } else {
  my @return; # save the returncode to use it
  if (defined($ARGV[1])) {
   print STDOUT "Parent: $mainpid requesting evalsafedo of $^X $ARGV[0] $ARGV[1] $mainpid\n";
   # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
   @return=evalsafedo($ARGV[0], $ARGV[1], $mainpid);
  } else {
   print STDOUT "Parent: $mainpid requesting evalsafedo of $^X $ARGV[0] new.tsv $mainpid\n";
   @return=evalsafedo($ARGV[0], "new.tsv", $mainpid); # FIXME need a better name if doing http post
  }
  # FIXME: this would forces success, instead stop within _sub uses the same return code
  # So this will never be shown
  print STDOUT "Parent: returned " . Dumper(@return) . " for $ARGV[0]\n";
  # And this will never be used
  exit(0);
  #exit($return);
 } # scalar ARGV
} # if main pid

# And this won't ever show
print STDOUT "Main: pid was $$\n";
BEGIN{
 print "$$ im also the parent\n";
}

# We want to get stdout, stderr and the exit code, maybe from "$?"
# because $? is a 16-bit word (art credit to @ikegami):
# +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
# | 15| 14| 13| 12| 11| 10|  9|  8|  7|  6|  5|  4|  3|  2|  1|  0|
# +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
#
# \-----------------------------/ \-/ \-------------------------/
#            Exit code            core     Signal that killed
#            (0..255)            dumped         (0..127)
#                                (0..1)
