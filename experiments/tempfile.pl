#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use File::Temp   qw(tempfile);      # For creating temporary files

my $test=1;
my $inputfile_fhtmp;
my $inputfile_name;

if ($test==1) { # to replicate locality of tempfile assignation
 ($inputfile_fhtmp, $inputfile_name) = tempfile("inputfile_XXXX", UNLINK=>1);
}
print $inputfile_fhtmp "Hello\nWorld\n\nThis is a test for reading from $inputfile_name\n";

