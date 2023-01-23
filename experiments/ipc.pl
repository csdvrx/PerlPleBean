#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Eval::Safe;

# Simply use a BEGIN block to detect the forking, and instead do or eval
BEGIN {
 unless (defined($ENV{PPB})) {
  # define it to the current pid if never defined
  $ENV{PPB} = "$$";
 } else { # unless defined $ENV{PPB}
  unless ("$$" == "$ENV{PPB}") {
   die ("PPB defined to $ENV{PPB} not matching $?");
  } # unless pid match
 } # unless defined $ENV{PPB}
} # BEGIN
END {
 # every variable will have been undef so use $$
 print STDERR "$$ ends returned $?\n";
} # END

# Detect if we're in cosmo
my $cosmo;

# Could also use Config but simpler:
# if ($Config{osname} =~ m/^cosmo/ || $Config{archname} =~ m/cosmo$/) {
if ($^O =~/cosmo/) {
 $cosmo=1;
}
print STDOUT "on $^O running $^X as $0\n";

my sub evalsafedo {
 my $what=shift; # @_[0]: program to eval
 my $read=shift; # @_[1]: file to read in input
 my $save=shift; # @_[2]: save output name
 print STDOUT "Parameters: what=$what save=$save read=$read\n";
 my $retval; # if we get $? save it here and use it as a return value
 # FIXME: should then be followed by any other flag
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
  # Perl reuses allocated memory whenever possible
  # cf https://www.oreilly.com/library/view/practical-mod_perl/0596002270/ch10.html
  # So prealloc to avoid any malloc issues, as we expect about 4kb of output
  my $size=4096;
  #my $char="\0";
  my $char=' ';
  my $chld_in= $char x $size;
  my $chld_out=$char x $size;
  my $chld_err=$char x $size;
  unless (-f $what) {
   print STDERR "evalsafedo: no such file to execute: $what\n";
   exit(-1); # FIXME: would kill the child, so the http server if we're not in a fork
  } # if file what
  unless (-f $read) {
   print STDERR "evalsafedo: no such file to ingest: $read\n";
   exit(-2);
  } else {
   open (my $binfh, "<", $read) or (die "could not open file $read: $!");
   $chld_in=undef;
   binmode $binfh;
   while (read ($binfh, my $onek, 1024)) {
    $chld_in .= $onek
   }
   close ($binfh);
  }
  #print STDOUT "evalsafedo got:\n" . Dumper($chld_in);
  print STDOUT "evalsafedo $what\n";
  my $eval = Eval::Safe->new(safe=>0); # slower and not working well anyway
  my $ret;
  { no strict;
    no warnings;
    open local *STDIN,  '>', \$chld_in or die "Cant redirect stdin: $!";
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
  print STDOUT "evalsafedo: $ret $? got >$chld_out< and >$chld_err<\n";
# Every end block is execute when exiting, so can't use that just for evalsafedo
END {
 print "Ending evalnsave $?\n";
}
  # remove EOL, even if CRLF
  $chld_out=~s/\x0D$//g;
  $chld_out=~s/\x0A$//g;
  $chld_err=~s/\x0D$//g;
  $chld_err=~s/\x0A$//g;
  print STDERR "evalsafedo: received STDOUT=$chld_out\n";
  print STDERR "evalsafedo: received STDERR=$chld_err\n";
} # sub



my $return; # save the returncode to use it
unless (defined($ARGV[2])) {
  print STDERR "Usage:\n$0 file.pl input.txt outputfilename";
  exit(0);
} else {
  print STDOUT "$$ requesting evalsafedo of $^X $ARGV[0] $ARGV[1] $ARGV[2] $$\n";
  $return=evalsafedo($ARGV[0], $ARGV[1], $ARGV[2], $$);
  print STDOUT "Parent: returned $return for $ARGV[0]\n";
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
