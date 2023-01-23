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

# Can do CLONE or CLONE_SKIP block
#CLONE_SKIP {
# print "Threading of $$ detected\n";
#}
BEGIN {
 print STDERR "Main: $$ starts\n"; # avoid autoflush issues by using stderr
}
END {
 print STDOUT "Main: $$ ends\n";
}

my $mainpid=$$;

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

our $override_exit = 0;
our $exit_return_value_shared;

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

# This wouldn't make any of these  private (even if it was in the sub)
use Eval::Safe;
# However this sub should be private
my sub evalnsafe {
 my $what=shift; # @_[0]: program to eval
 my $save=shift; # @_[1]: save output name
 my $cpid=shift; # @_[2]: pre-existing child pid
 my $defuse; # if set, will specify what's executed should not even try to IPC again
 # FIXME: should then be followed by any other flag
 unless (defined($cpid)) {
  die "Parent: evalnsafe: Tapping out to avoid forkbomb behavior of $^X due to unknown previous child pid $pid";
 }
 unless (defined($pid)) {
  die "Parent: evalnsafe: Tapping out to avoid forkbomb behavior of $^X due to unknown current child pid $pid";
 }
 if ($cpid eq $pid) {
  # the pid hasn't changed, which means we could enter in a recursive behavior (fork-bomb)
  # prevent that by saying this is final
  print STDERR "Parent: evalnsafe: RISK OF FORKBOMB $^X due to previous child pid $cpid matching current child pid $pid\n";
  # Can we mitigate that?
 }
 unless (defined($what)) {
  print STDERR "Parent: evalnsafe: what to eval undefined\n";
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
  # Do the bare minimum to prevent abuse with non-printable ascii
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
   print STDERR "Parent: evalnsafe: no such file: $what\n";
   exit(-1); # FIXME: would kill the child, so the http server if we're not in a fork
  } # if file what
  if (1) {
   print STDOUT "Parent: evalnsafe $what\n";
   if (1) { ## Test branch
   print STDOUT "THIS IS BRANCH TESTING\n";
    use Safe;
    my $eval = Eval::Safe->new(safe=>0); # slower and not working
   # safe need PerlIO::Layer which needs a bunch of XS lzma etc
    # Save old filehandles
    #open(my $oldout, ">&STDOUT") or die "Cant save STDOUT: $!";
    #open(my $olderr, ">&STDERR") or die "Cant save STDERR: $!";
    # Alternative: use select to also use them as needed:
    # by selecting them before using:
    # my $new, ">", \my $string;
    ## switch old and new: make $new the default fh for output
    # my $old = select $new;
    # say "to selected default"; # goes into string
    ## restore STDOUT as the default for output
    # select $old;
    # Then use new filehandles for the real thing
    #my ( $REAL_STDIN, $REAL_STDOUT, $REAL_STDERR );
    #BEGIN {
    # open $REAL_STDIN,  '<&='  . fileno(*STDIN);
    # open $REAL_STDOUT, '>>&=' . fileno(*STDOUT);
    # open $REAL_STDERR, '>>&=' . fileno(*STDERR);
    #}
    # So if we want the real ones
    #local *STDIN = $REAL_STDIN;
    #local *STDOUT = $REAL_STDOUT;
    #local *STDERR = $REAL_STDERR;
    # If we want to capture, use in-memory filehandle, but fileno will return negative numbers
    # IPC::Open3 is not supposed to work when your filehandles are variables
    open local *STDOUT, '>', \$chld_out or die "Cant redirect stdout: $!";
    open local *STDERR, '>', \$chld_err or die "Cant redirect stderr: $!";
    # STDERR is line buffered.
    # if we must have STDOUT line buffered instead of block buffered
    # (which is the default for when not connected to a terminal)
    # cf perlvar for $|
    #STDOUT->autoflush(1); # could also fool the program with pty
    # like my $h = harness $cmd, \undef, '>pty>', \$out,
    # FIXME: we want the exit code, so insure
    #$eval->do ($what);
    my $ch = $eval->do ($what);
   print STDOUT "TESTING " . defined($ch) . " got $chld_out and $chld_err\n";
    # so let's instead read the file and prefix it with something to grab the exit
    #use File::Slurper qw(read_text);
    #my $code = read_text($what);
END {
 print "Bad\n";
}

    # restore the old ones
    # open(STDOUT, ">&", $oldout) or die "Cant restore \$oldout: $!";
    # open(STDERR, ">&", $olderr) or die "Cant restore \$olderr: $!";
    #print Dumper($eval);
   } else { ## working branch
   my $eval = Eval::Safe->new(safe=>0); # yolo!
   print STDOUT "THIS IS BRANCH WORKING\n";
    # This 1) won't capture syswrite, would need to tie the localized STDOUT + implement PRINT, PRINTF and WRITE to append to the string and 2) won't capture spawned processes: Capture::Tiny does both by reopening STDOUT tied to a File::Temp (with brings its unlink0/unlink1 problems)
    open local *STDOUT, '>', \$chld_out or die "open in-memory file: $!";
    open local *STDERR, '>', \$chld_err or die "Cant redirect stderr: $!";
    my $ch = $eval->do ($what);
    #print Dumper($eval);
   }
  }
  #if (0) {
  ## FIXME: could pass more arguments after the pid
  # unless ($defuse) {
  #  print STDOUT "Parent: run: starting $^X $ARGV[0] $pid\n";
  #  $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]", "$pid"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
  # } else {
  #  print STDOUT "Parent: run: CAUTION: $^X $ARGV[0] FINAL\n";
  #  $run3=IPC::Run3::run3 (["$^X", "$ARGV[0]", "FINAL"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
  # }
  #}
  # FIXME: to be sent by HTTP post
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  $chld_err=~s/\x0D$//g;
  $chld_err=~s/\x0A$//g;
  print STDERR "Parent: evalnsafe: received STDOUT=$chld_out\n";
  print STDERR "Parent: evalnsafe: received STDERR=$chld_err\n";
  #print STDOUT "Parent: run: exiting with $run3\n";
  # return($run3);
  # FIXME: maybe better to exit
  # so exit with the same value
  #exit($run3);
  # FIXME: problem: no more run3, so just exit
  return(0); # FIXME: due to eval safe issue, this is implied: won't return if it dies lol
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Parent: evalnsafe: nothing past this: ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub evalnsafe

my sub run {
 use IPC::Run3;
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
} # my sub run


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
  print STDOUT ("Parent: exiting ASAP as forking is done and no eval is required\n");
  exit(0)
 } else {
  #if (defined($ARGV[2])) {
  # print STDERR "got argv2 $ARGV[2]\n";
  # die;
  #}
  my $return;
  if (0) { # evalnsafe
   print STDOUT "Parent: $mainpid $pid requesting evalnsafe of $^X $ARGV[0] $pid";
   if (defined($ARGV[1])) {
    print STDOUT " with output filename $ARGV[1]\n";
    # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
    $return=evalnsafe($ARGV[0], $ARGV[1], $mainpid);
   } else {
    print STDOUT "\n";
    $return=evalnsafe($ARGV[0], "new.tsv", $mainpid); # FIXME need a better name if doing http post
   }
  } else { # evalnsafe or run
   print STDOUT "Parent: $mainpid $pid requesting run of $^X $ARGV[0] $pid";
   if (defined($ARGV[1])) {
    print STDOUT " with output filename $ARGV[1]\n";
    # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
    $return=run($ARGV[0], $ARGV[1], $mainpid);
   } else {
    print STDOUT "\n";
    $return=run($ARGV[0], "new.tsv", $mainpid); # FIXME need a better name if doing http post
   } # run
  }
  # FIXME: this would forces success, instead stop within _sub uses the same return code
  # So this will never be shown
  print STDOUT "Parent: retuned $return for $ARGV[0]\n";
  # And this will never be used
  exit(0);
 } # scalar ARGV
} # if main pid

# And this won't ever show
print STDOUT "Main: pid was $$\n";

