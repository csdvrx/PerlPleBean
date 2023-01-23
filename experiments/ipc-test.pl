#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

# Let's compare evalsafedo to ipcrun3run and ipcrunrun
my $testwhat=4;
# if 1: tests instead evalsafedo:
#  - if exit() in what's run, problem: no stdout or stderr even if
#  - other problem: if diamond operator, uses the parent cmdline
#  stuff was there before, and not due to buffering?
#  - otherwise, get stdout and everything
# if 2: tests instead ipcrun3run: get the exit code
#   FIXME: but no longer the output? WTF?
# if 3: tests instead ipcrunrun:
# FIXME 2 and 3 not working yet in APE mode: forksbomb if die
# TBD if 4 tests instead runsafedo: hopefully will get both when done
#
# The main drawback of evalsafedo is that any exit within the code
# that's executes gets us... nothing in stdout

BEGIN {
 my $CNTR;
 if (defined($ENV{PPB})) {
  unless (0+"$$" == 0+"$ENV{PPB}") {
   if (defined($ENV{'CNTR'})) {
    $CNTR=$ENV{'CNTR'};
   } else {
    $ENV{'CNTR'}=1;
    $CNTR=1;
   }
   if ($CNTR>20) {
    die ("Fork risk as $ENV{PPB} not $$\n");
   }
 }
}

END {
if (defined($ENV{'CNTR'})) {
 $ENV{'CNTR'}=$ENV{'CNTR'}+1;
} else {
 $ENV{'CNTR'}=1;
}
}

my ( $REAL_STDIN, $REAL_STDOUT, $REAL_STDERR );
open $REAL_STDIN,  '<&='  . fileno(*STDIN);
open $REAL_STDOUT, '>>&=' . fileno(*STDOUT);
open $REAL_STDERR, '>>&=' . fileno(*STDERR);
local *STDIN = $REAL_STDIN;
local *STDOUT = $REAL_STDOUT;
STDOUT->autoflush(1);  # might help?
 select(STDOUT); $|=1; # doesn't help
local *STDERR = $REAL_STDERR;
print $REAL_STDERR "$?\n";
print $REAL_STDOUT "Done\n";
}

#
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


#####################################################################
# APPerl no-forkbomb ~= like POSIX named semaphore but %ENV instead
#####################################################################

# Simply use a BEGIN block to detect the forking, and instead do or eval
BEGIN {
 unless (defined($ENV{PPB})) {
  # define it to the current pid if never defined
  $ENV{PPB} = "$$";
 } else {
  # we're already running...
  if (defined($ENV{PPBIPC})) {
   # ... and we want an IPC
   # could use do, eval or exec
   # FIXME: do can get the returned code with a END block using $?
   # - eval never returns if successful https://perldoc.perl.org/functions/eval
   #   but gives us @_ with the problems encountered
   # - do will use @INC if given an unqualified path
   # (ie a relative not starting with .)
   # So qualify with ./
   my $file = "./$ENV{PPBIPC}";
   # FIXME: might use the exec to open an url (exec http file since vscode opened when exec'in the .pl)
   if (0) {
    # use File::Slurper qw(read_text);
    # my $code = read_text($ENV{PPBIPC});
    # #print STDOUT ($code);
    # # add a custom end block to get the return
    # $code = $code . "END{\n";
    # $code = $code . "print STDOUT \"\$? returned by PPBIPC\n\";";
    # $code = $code . "}\n";
    # eval("$code");
    # print STDOUT @_ if @_;
   } else {
    unless (my $return = do $file) {
     print STDOUT "Cant parse $file: $@" if $@;
     print STDOUT "Cant do $file: $!"    unless defined $return;
     print STDOUT "Cant run $file"       unless $return;
    } else { # unless defined $ENV{PPBIPC}
     # This avoids forkbombing in APE mode
     print STDERR "Success $?";
     die ("$?");
    } # unless return
   } # if 0|1
  } else { # if defined $ENV{PPBIPC}
     die ("Nothing to do");
  } # if defined $ENV{PPBIPC}
  #exec("$ENV{PPBIPC}"); # never returns if successful
  #print STDOUT ("success $ENV{PPBIPC}");
 } # unless defined $ENV{PPB}
} # BEGIN
END {
 # every variable will have been undef so use $$
 print STDOUT "Main: $$ ends returned $?\n";
} # END

# Like CLONE, CLONE_SKIP is called once per package; however, it is called just
# before cloning starts, and in the context of the parent thread. If it returns
# a true value, then no objects of that class will be cloned; or rather, they
# will be copied as unblessed, undef values
# Like CLONE, CLONE_SKIP is currently called with no parameters other than the invocant package name
# the return value should be a single 0 or 1 value
# FIXME: could recycle CLONE or CLONE_SKIP to detect perl interal fork use of threading

# We could prefix things with that to detect other forkbomb risks
my $mainpid=$$;

# This is ipc-test.pl based on the begin.pl approach, so by construction it
# requires IPC::Run to be in main, past the "Chinese wall" of a BEGIN block
# inside which fork() happens: then the child will never see past that wall
#
# This allows a simpler design with 2 simple scenarios around the wall:
#  - before the wall, the regular HTTP serving code only requesting IPC by
#    calling this same script but with arguments: what to run, output name
#  - after the wall, only the IPC::Run code actually doing the requested IPC
#    and bailing out early if it's not required (if there's no argument) as
#    will be the case when the server is first started

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
 my $what=shift;  # @_[0]: program to eval
 my $read=shift; # @_[1]: read input file
 my $save=shift;  # @_[2]: save output name
 my $ppid=shift;  # @_[3]: pre-existing parent pid
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
   print STDERR "Parent: evalsafedo: no such file to execute $what\n";
   return(-1); # FIXME: exit would kill the child, so the http server if we're not in a fork
  } # if file what
  unless (-f $read) {
   print STDERR "Parent: evalsafedo: no such file to pass as param: $read\n";
   return(-2); # FIXME: wxit would kill the child, so the http server if we're not in a fork
  } # -f read
  print STDOUT "Parent: evalsafedo $what\n";
  if (2) { ## Test branch
  print STDOUT "Parent: evalsafedo: THIS IS BRANCH TESTING\n";
   use Safe;
   my $eval = Eval::Safe->new(safe=>0); # slower and not working well anyway
   # Also would require PerlIO::Layer and a buch of XS
   # Save old filehandles
   # open(my $oldout, ">&STDOUT") or die "Cant save STDOUT: $!";
   # open(my $olderr, ">&STDERR") or die "Cant save STDERR: $!";
   #use Symbol "gensym";
   ## if vivifications is used for STDERR problems like
   #my $Pin  = new IO::Handle;
   #$Pin->fdopen(10, "w");
   #my $Pin  = new IO::Handle;
   #$Pin->fdopen(11, "r");
   #my $Pin  = new IO::Handle;
   #$Pin->fdopen(12, "r");
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
   # IPC::Open3 is not supposed to work when your filehandles are variablesa
   my $retval;
   {
    open local *STDOUT, '>', \$chld_out or die "Cant redirect stdout: $!";
    open local *STDERR, '>', \$chld_err or die "Cant redirect stderr: $!";
    # STDERR is line buffered.
    # if we must have STDOUT line buffered instead of block buffered
    # (which is the default for when not connected to a terminal)
    # cf perlvar for $|
    STDOUT->autoflush(1); # could also fool the program with pty
    # select(STDOUT); $|=1; # doesn't help
    # like my $h = harness $cmd, \undef, '>pty>', \$out,
    #$eval->do ($what);
    eval {
     $retval = $eval->do ($what, $read);
    };
    #close (STDOUT);
    #close (STDERR);
    if ($@) {
     print STDOUT "Problem: got $retval $? " . Dumper($@);
    }
   }
   if (defined($retval)) { 
    print STDOUT "Parent: evalsafedo: TESTING " . defined($retval) . " got $chld_out and $chld_err\n";
   } else {
    print STDOUT "Parent: evalsafedo: TESTING obtained no retval got $chld_out and $chld_err\n";
   }
   # so let's instead read the file and prefix it with something to grab the exit
   #use File::Slurper qw(read_text);
   #my $code = read_text($what);
   # restore the old ones
   # open(STDOUT, ">&", $oldout) or die "Cant restore \$oldout: $!";
   # open(STDERR, ">&", $olderr) or die "Cant restore \$olderr: $!";
   #print Dumper($eval);
  } else { ## working branch
   my $eval = Eval::Safe->new(safe=>0); # yolo!
   print STDOUT "Parent: evalsafedo: THIS IS BRANCH WORKING\n";
   # Limit to the local fh approach:
   # - won't capture syswrite, would need to tie the localized STDOUT +
   # implement PRINT, PRINTF and WRITE to append to the string
   # - won't capture spawned processes: Capture::Tiny does both by reopening
   # STDOUT tied to a File::Temp (with brings its unlink0/unlink1 problems)
   #
   open local *STDOUT, '>', \$chld_out or die "Open in-memory file: $!";
   open local *STDERR, '>', \$chld_err or die "Cant redirect stderr: $!";
   # FIXME: if the code of $what contains an exit:
   #  - we won't get anything!!
   #  - we just get the return code in $retval
   STDOUT->autoflush(1); # and this won't help
   {
    print STDER "ok:\n";
    $retval = $eval->do ($what);
    print STDER "ok??\n";
    # this doesn't help
    # my $ch = do ("./" . $what);
   }
# Every end block is execute when exiting, so can't use that just for evalsafedo
#END {
# print "Ending evalnsave\n";
#}
   print STDOUT "Parent: evalsafedo: returned with $retval $?\n";
  }
  #FIXME: to be sent by HTTP post to as the http server will run in child
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  $chld_err=~s/\x0D$//g;
  $chld_err=~s/\x0A$//g;
  print STDERR "Parent: evalsafedo: received STDOUT=$chld_out\n";
  print STDERR "Parent: evalsafedo: received STDERR=$chld_err\n";
  if (defined($retval)) {
   print STDERR "Parent: evalsafedo: obtained retval=$retval\n";
  } else { # if defined retval
   # FIXME FIXME FIXME problem: can means work well w no exit code, or div by 0?
   if ($chld_out =~ m/^Err:/) {
    my $errnum=$chld_out;
    $errnum=~s/^Err://g;
    $errnum=~s/ //g;
    if ($errnum =~ m/[-]?[0-9]+/) {
     $retval=$errnum;
     $retval=~s/[^-]?[^\d]//g;
     print STDERR "Parent: evalsafedo: DIT NOT OBTAIN retval, assuming retval=$retval based on errnum $errnum\n";
    } # if errnunm match -?\d
   } else { # if child_out match Err:
    $retval=0;
    print STDERR "Parent: evalsafedo: DIT NOT OBTAIN retval, assuming retval=0 since no Err string\n";
   } # if child_out match Err:
  } # if defined retval
  return($retval); # FIXME: due to eval safe issue, this is implied: won't return if it dies lol
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Parent: evalsafedo: nothing past this: ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub evalsafedo


my sub ipcrun3run {
 use IPC::Run3;
 my $what=shift;  # @_[0]: program to run
 my $read=shift; # @_[1]: read input file
 my $save=shift;  # @_[2]: save output name
 my $ppid=shift;  # @_[3]: pre-existing parent pid
 my $defuse; # if set, will specify what's executed should not even try to IPC again
 my $retval; # if we get $? save it here and use it as a return value
 # FIXME: should then be followed by any other flag
 unless (defined($ppid)) {
  die "Parent: ipcrun3run: Tapping out to avoid forkbomb behavior of $^X due to unknown parent pid $pid:$$";
 }
 unless ($ppid eq $$) {
  # the pid has changed, which means we could enter in a recursive behavior (fork-bomb)
  # prevent that by saying this run is final
  print STDERR "Parent: ipcrun3run: RISK OF FORKBOMB $^X due to parent pid $ppid NOT matching current parent pid $$\n";
  # Can we mitigate that?
  $defuse=1;
 }
 unless (defined($what) && -f $what) {
  print STDERR "Parent: ipcrun3run: not file $what to execute\n";
  return(-1);
 }
 unless (defined($read) && -f $read) {
  print STDERR "Parent: ipcrun3run: no file $read to pass as param\n";
  return (-2);
 }
 if (1) {
  # The core issue with APPerl is $^X==$0, while we may want to run $^X $ARGV[0]
  # Even if the above construct will hide from child anything below the barrier,
  # which should guarantee this will not happen, let's still be safe and check
  # what we execute here isn't what is already running (a fork bomb otherwise!)
  my $fpart0=$what;
  # recode windows \ to unix / then keep the tail
  $fpart0=~s/\\/\//g;
  $fpart0=~s/.*\///g;
  my $fpartarg0=$ARGV[0];
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
  # Do the bare minimum to prevent abuse with non-printable ascii and separators
  $what =~ s/[\0-\x1f].*$//g;
  $what =~ s/[';|"]//g;
  # FIXME: could also recode Windows \ and \\
  # This is no longer necessary thanks to the BEGIN block
  #if ($fpart0 eq $fpartarg0) {
  # die "Parent: ipcrun3run: Tapping out to avoid forkbomb behavior of $^X due to $fpartarg0 matching $fpart0";
  #} else {
  #  print STDOUT "Parent: ipcrun3run: $^X with $what (and $read ) instead of $fpart0 from $0\n";
  #}
  # Perl reuses allocated memory whenever possible
  # cf https://www.oreilly.com/library/view/practical-mod_perl/0596002270/ch10.html
  # So prealloc to avoid any malloc issues, as we expect about 4kb of output
  my $size=4096;
  #my $char="\0";
  my $char=' ';
  my $chld_in= $char x $size;
  my $chld_out=$char x $size;
  my $chld_err=$char x $size;
  unless (defined ($what) && -f $what) {
   print STDERR "Parent: ipcrun3run: no such file to exec: $what\n";
   #exit(-1); # FIXME: would kill the http server we're not inside a IPC::Run
   return(-1);
  }
  unless (defined ($read) && -f $read) {
   print STDERR "Parent: ipcrun3run: no such file to pass as param: $read\n";
   return(-2);
  }

  # FIXME: could pass more arguments after the pid
  unless (defined ($defuse)) {
    # FIXME: thanks to the anti forkbomb BEGIN block, we could even do:
    print STDOUT "Parent: ipcrun3run: starting $^X $ARGV[0] $ARGV[1] $ARGV[2] $ppid\n";
    $ENV{PPBIPC}="$ARGV[0]"; # FIXME: poorman IPC within APPerl APE
    $retval=IPC::Run3::run3 (["$^X", "$ARGV[0]", "$ARGV[1]", "$ARGV[2]", "$ppid"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
    # But let's do it simply
    #print STDOUT "Parent: ipcrun3run: starting $^X $what $ppid\n";
    #$ENV{PPBIPC}="$what"; # FIXME: poorman IPC within APPerl APE
    #$retval=IPC::Run3::run3 (["$^X", "$what", "$ppid"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
    print STDOUT "Checking $?\n";
  } else {
    $ENV{PPBIPC}="$what"; # FIXME: poorman IPC within APPerl APE
    print STDOUT "Parent: ipcrun3run: defuse=$defuse CAUTIOUSLY starting $^X $what $read FINAL\n";
    $retval=IPC::Run3::run3 (["$^X", "$what", "$read", "FINAL"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run3 error $!");
    # "Note that a true return value from run3 doesn't mean that the command
    # had a successful exit code. Hence you should always check $?."
    print STDOUT "Checking $?\n";
    # FIXME: could we also abuse environment variables to pass return codes
    #if (defined($ENV{PPBERR})) {
    # print STDOUT "ERR $ENV{PPBERR}\n";
    #}
  }
  print STDOUT "Parent: ipcrun3run returned with retval $retval $?\n";
  # FIXME: to be sent by HTTP post
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  print STDERR "Parent: ipcrun3run: received STDOUT=$chld_out\n";
  print STDERR "Parent: ipcrun3run: received STDERR=$chld_err\n";
  if (defined($retval)) {
   print STDERR "Parent: ipcrun3run: obtained retval=$retval\n";
  } else {
   print STDERR "Parent: ipcrun3run: DIT NOT OBTAIN retvalretval\n";
  }
  return($retval); # FIXME: maybe better to exit
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Parent: ipcrun3run: nothing past this: ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub ipcrun3run


use IPC::Run qw(timeout);
my sub ipcrunrun {
 my $what=shift;  # @_[0]: program to run
 my $read=shift; # @_[1]: read input file
 my $save=shift;  # @_[2]: save output name
 my $ppid=shift;  # @_[3]: pre-existing parent pid
 my $defuse; # if set, will specify what's executed should not even try to IPC again
 my $retval; # if we get $? save it here and use it as a return value
 # FIXME: should then be followed by any other flag
 unless (defined($ppid)) {
  die "Parent: ipcrunrun: Tapping out to avoid forkbomb behavior of $^X due to unknown parent pid $pid:$$";
 }
 unless ($ppid eq $$) {
  # the pid has changed, which means we could enter in a recursive behavior (fork-bomb)
  # prevent that by saying this run is final
  print STDERR "Parent: ipcrunrun: RISK OF FORKBOMB $^X due to parent pid $ppid NOT matching current parent pid $$\n";
  # Can we mitigate that?
  $defuse=1;
 }
 unless (defined($what) && -f $what) {
  print STDERR "Parent: ipcrun3run: not file $what to execute\n";
  return(-1);
 }
 unless (defined($read) && -f $read) {
  print STDERR "Parent: ipcrun3run: no file $read to pass as param\n";
  return (-2);
 }
 if (1) {
  # The core issue with APPerl is $^X==$0, while we may want to run $^X $ARGV[0]
  # Even if the above construct will hide from child anything below the barrier,
  # which should guarantee this will not happen, let's still be safe and check
  # what we execute here isn't what is already running (a fork bomb otherwise!)
  my $fpart0=$what;
  # recode windows \ to unix / then keep the tail
  $fpart0=~s/\\/\//g;
  $fpart0=~s/.*\///g;
  my $fpartarg0=$ARGV[0];
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
  # Do the bare minimum to prevent abuse with non-printable ascii and separators
  $what =~ s/[\0-\x1f].*$//g;
  $what =~ s/[';|"]//g;
  # FIXME: could also recode Windows \ and \\
  # This is no longer necessary thanks to the BEGIN block
  #if ($fpart0 eq $fpartarg0) {
  # die "Parent: ipcrunrun: Tapping out to avoid forkbomb behavior of $^X due to $fpartarg0 matching $fpart0";
  #} else {
  #  print STDOUT "Parent: ipcrunrun: $^X with $what (and $read ) instead of $fpart0 from $0\n";
  #}
  # Perl reuses allocated memory whenever possible
  # cf https://www.oreilly.com/library/view/practical-mod_perl/0596002270/ch10.html
  # So prealloc to avoid any malloc issues, as we expect about 4kb of output
  my $size=4096;
  #my $char="\0";
  my $char=' ';
  my $chld_in= $char x $size;
  my $chld_out=$char x $size;
  my $chld_err=$char x $size;
  unless (defined($what) && -f $what) {
   print STDERR "Parent: ipcrun3run: not file $what to execute\n";
   return(-1);
  }
  unless (defined($read) && -f $read) {
   print STDERR "Parent: ipcrun3run: no file $read to pass as param\n";
   return (-2);
  }
  if (1) {
  # FIXME: could pass more arguments after the pid
   unless (defined ($defuse)) {
    # FIXME: thanks to the anti forkbomb BEGIN block, we could even do:
    print STDOUT "Parent: ipcrunrun: starting $^X $ARGV[0] $ARGV[1] $ppid\n";
    $ENV{PPBIPC}="$ARGV[0]"; # FIXME: poorman IPC within APPerl APE
    $retval=IPC::Run3::run3 (["$^X", "$ARGV[0]", "$ARGV[1]", "$ppid"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run error $!");
    # But let's do it simply
    #$ENV{PPBIPC}="$ARGV[0]"; # FIXME: poorman IPC within APPerl APE
    #print STDOUT "Parent: ipcrunrun: starting $^X $ARGV[0] $ppid\n";
    #$retval=IPC::Run::run (["$^X", "$ARGV[0]", "$ppid"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run error $!");
    print STDOUT "Checking $?\n";
   } else {
    $ENV{PPBIPC}="$what"; # FIXME: poorman IPC within APPerl APE
    print STDOUT "Parent: ipcrunrun: defuse=$defuse CAUTIOUSLY starting $^X $what $read FINAL\n";
    $retval=IPC::Run::run (["$^X", "$what", $read, "FINAL"], \$chld_in, \$chld_out, \$chld_err) or print STDERR ("run error $!");
    print STDOUT "Checking $?\n";
    # FIXME: could we also abuse environment variables to pass return codes
    #if (defined($ENV{PPBERR})) {
    # print STDOUT "ERR $ENV{PPBERR}\n";
    #}
   }
  } # if 1
  print STDOUT "Parent: ipcrunrun returned with $retval $?\n";
  # FIXME: to be sent by HTTP post
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  print STDERR "Parent: ipcrunrun: received STDOUT=$chld_out\n";
  print STDERR "Parent: ipcrunrun: received STDERR=$chld_err\n";
  if (defined($retval)) {
   print STDERR "Parent: ipcrunrun: obtained retval=$retval\n";
  } else {
   print STDERR "Parent: ipcrunrun: DIT NOT OBTAIN retvalretval\n";
  }
  return($retval); # FIXME: maybe better to exit
  #exit(0);
 } # unless defined what
 # Nothing should go past this point
 print STDERR "Parent: ipcrunrun: nothing past this: ASSERTION BROKEN\n";
 die("Tapping out as this should NOT have happened\n");
} # my sub ipcrunrun

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
  my $return1; # save the returncode to use it
  my $return2; # save the returncode to use it
  if ($testwhat ==1) { # evalsafedo
    print STDOUT "Parent: $mainpid requesting evalsafedo of $^X $ARGV[0] $ARGV[1] $ARGV[2] $mainpid\n";
    # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
    $return1=evalsafedo($ARGV[0], $ARGV[1], $ARGV[2], $mainpid);
  } elsif ($testwhat ==2) { # ipcrun3run
    print STDOUT "Parent: $mainpid requesting ipcrun3run of $^X $ARGV[0] $ARGV[1] $ARGV[2] $mainpid\n";
    # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
    $return1=ipcrun3run($ARGV[0], $ARGV[1], $ARGV[2], $mainpid);
  } elsif ($testwhat ==3) { # ipcrunrun
    print STDOUT "Parent: $mainpid requesting ipcrunrun of $^X $ARGV[0] $ARGV[1] $ARGV[2] $mainpid\n";
    # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
    $return1=ipcrunrun($ARGV[0], $ARGV[1], $ARGV[2], $mainpid);
  } elsif ($testwhat ==4) { # evalsafedo, then if successfull, ipcrunrun
    # FIXME: add other arguments here, and sanitize them a minimum to avoid code injection
    print STDOUT "Parent: $mainpid requesting step1 evalsafedo of $^X $ARGV[0] $ARGV[1] $ARGV[2] $mainpid\n";
    $return1=evalsafedo($ARGV[0], $ARGV[1], $ARGV[2], $mainpid);
    if (defined($return1)) {
     print STDOUT "Parent: $mainpid step1 result: $return1\n";
     if ($return1=~m/^[-]?[0-9]+$/) {
      print STDOUT "Parent: $mainpid requesting step2 ipcrunrun of $^X $ARGV[0] $ARGV[1] $ARGV[2] $mainpid\n";
      $return2=ipcrunrun($ARGV[0], $ARGV[1], $ARGV[2], $mainpid);
      if (defined($return2)) {
       print STDOUT "Parent: $mainpid step2 result: $return2\n";
      } else { # if defined returned
      print STDOUT "Parent: $mainpid NOT requesting step2 ipcrunrun since step1 failed\n";
      } # if defined returned
     } # if return1 ==0
    } else { # if defined return1
     print STDOUT "Parent: $mainpid step1 DIT NOT obtain result: $return1\n";
    } # if defined return1
  } # testwhat
  my $return;
  if (defined($return2)) {
   $return=$return2;
  } elsif (defined($return1)) {
   $return=$return1;
  } else {
   # it couldn't even pass evalsafedo, meaning a problem as serious as divby0
   $return="FAILED";
  }
  # FIXME: this would forces success, instead stop within _sub uses the same return code
  # So this will never be shown
  print STDOUT "Parent: returned $return for arg0: $ARGV[0] arg1: $ARGV[1] arg2: $ARGV[2] \n";
  # And this will never be used
  if ($return =~ m/^[0-9]+$/) {
   exit($return);
  } else {
   exit(-1);
  } # unless return
 } # scalar ARGV
} # if main pid

# And this won't ever show
print STDOUT "Main: pid was $$\n";
