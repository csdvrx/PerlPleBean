#!/usr/bin/perl
## Modern perl
use v5.14;                      # for /r match+assign on regexp and ~~ smartmatch
use strict;
use warnings;
use open qw(:std);              # should use unicode, but (:std :utf8) gives mojibake

print STDOUT "Hello $^X $0 \n";

