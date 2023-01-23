use strict;
use warnings;
use Time::HiRes qw(clock usleep nanosleep gettimeofday);
use Data::Dumper;

my @gtod;

# This shows gtod seems more reliable in this usecase;
@gtod= gettimeofday(); # seconds, microseconds
print "GTOD:\t$gtod[0]\t$gtod[1]\n";

my $start = clock(); # start, reports seconds
print "Start: $start s,\tie " . $start*1e3 . " ms,\tie " . $start*1e6 . " us: should be time of process start\n";
my $clock = clock() -$start;
print "Clock: $clock s,\tie " . $clock*1e3 . " ms,\tie " . $clock*1e6 . " us\n";

@gtod= gettimeofday(); # seconds, microseconds
print "GTOD:\t$gtod[0]\t$gtod[1]\n";

my $microseconds;
$microseconds = 1_000_000; # 1s
$clock = clock() -$start;
my $click = $clock;
print "Clock: $clock s,\tie " . $clock*1e3 . " ms,\tie " . $clock*1e6 . " us\n";
print "\nRedoing after usleep\t$microseconds us,\tie " . $microseconds*1E-3 ." ms,\tie " . $microseconds*1E-6 . " s\n";
#sleep(1);
usleep($microseconds);
$clock = clock() - $start;
print "Clock: $clock s,\tie " . $clock*1e3 . " ms,\tie " . $clock*1e6 . " us\n";

@gtod= gettimeofday(); # seconds, microseconds
print "GTOD:\t$gtod[0]\t$gtod[1]\n";

# Try another delta
my $delta=($clock-$click);
print "Elapsed: $delta s,\tie " . $delta*1e6 . " us: seems wrong, maybe usleep used clock\n";

$microseconds= 500_000; # 0.5E6 us = 0.5s
$clock = clock() -$start;
$click = $clock;
print "Clock: $clock s,\tie " . $clock*1e3 . " ms,\tie " . $clock*1e6 . " us\n";
print "\nRedoing after usleep\t$microseconds us,\tie " . $microseconds*1E-3 ." ms,\tie " . $microseconds*1E-6 . " s\n";
#sleep(1);
usleep($microseconds);
$clock = clock() - $start;
print "Clock: $clock s,\tie " . $clock*1e3 . " ms,\tie " . $clock*1e6 . " us\n";

#my $nanoseconds = 2_000_000; # 2E6 ns = 2E-3 s = 2ms = 2E3 us
my $nanoseconds = 1_000_000; # 1E6 ns = 1E-3 s = 1ms = 1E3 us
print "Redoing after nanosleep\t$nanoseconds us,\t ie " . $nanoseconds*1E-6 ." ms,\tie " . $nanoseconds*1E-9 . " s\n";
$click = clock() - $start;
print "Click: $click s,\tie " . $click*1e3 . " ms,\tie " . $click*1e6 . " us\n";
nanosleep($nanoseconds);
$clock = clock() - $start;
print "Clock: $clock s,\tie " . $clock*1e3 . " ms,\tie " . $clock*1e6 . " us\n";

@gtod= gettimeofday(); # seconds, microseconds
print "GTOD:\t$gtod[0]\t$gtod[1]\n";

$delta=($clock-$click); #*1e6;
print "Elapsed: $delta s,\tie " . $delta*1e6 . " us: also seems wrong\n";

@gtod= gettimeofday(); # seconds, microseconds
print "GTOD:\t$gtod[0]\t$gtod[1]\n";
