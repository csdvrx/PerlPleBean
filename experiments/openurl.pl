#!/usr/bin/perl

use strict;
use warnings;

use List::Util qw( max );
use Env;

# Detect the OS: 4 measures for each:
# - 2 very precise (values of variables) worth 10 points
# - 2 less precise (existence of variables) worth 5 points
# Expected total: 30 points
# Special case for Linux: replace 1 precise measurement by 10 rough ones worth about 1 point each
#
######################### Windows
my $win=0;

if ( defined($ENV{'OS'}) && $ENV{'OS'} =~ m/^Windows/) {
 $win=+10;
}
if ( defined ($ENV{'WINDIR'}) && $ENV{'WINDIR'} =~ m/[A-Z]:\\Windows/i) {
 $win+=10;
}
if (defined($ENV{'PROGRAMFILES'})) {
 $win+=5;
}
if (defined($ENV{'USERPROFILE'})) {
 $win+=5;
}

######################## WSL
my $wsl=0;

if (defined ($ENV{'WSL_INTEROP'}) && $ENV{'WSL_INTEROP'} =~ m/^\/run\/WSL/) {
 $wsl+=10;
}
if (defined ($ENV{'UNAME'}) && $ENV{'UNAME'} =~ m/microsoft-standard-WSL/) {
 $wsl+=10;
}
if ($ENV{'WSL_DISTRO_NAME'}) {
 $wsl+=5;
}
if ($ENV{'WSLENV'}) { # not ideal: also true in cmdprompt and powershell
 $wsl+=5;
}

######################## MacOS
my $mac=0;

if (defined($ENV{'__CFBundleIdentifier'})) { # =~ m/com.apple.Terminal/ || com.googlecode.iterm2
 $mac+=10;
}
if (defined($ENV{'DISPLAY'}) && $ENV{'DISPLAY'} =~ m/com.apple/) {
 $mac+=10;
}

if (defined($ENV{'XPC_SERVICE_NAME'})) {
 $mac+=5;
} elsif (defined($ENV{'XPC_FLAGS'})) {
 $mac+=5;
}
if (defined($ENV{'TERM_PROGRAM_VERSION'})) {
 $mac+=5;
} elsif (defined($ENV{'TERM_PROGRAM'})) {
 $mac+=5;
}

######################## Linux proper

my $lnx=0;

if (defined($ENV{'DBUS_SESSION_BUS_ADDRESS'}) && $ENV{'DBUS_SESSION_BUS_ADDRESS'} =~ m/\/run\//) {
 $lnx+=10;
}
if (defined($ENV{'XDG_RUNTIME_DIR'}) && $ENV{'XDG_RUNTIME_DIR'} =~ m/\/run\//) {
 $lnx+=10;
} else {
 # A typical linux distribution has about 13 XDG_ keys, so should get at least 10 points that way
 foreach my $k (keys %ENV) {
  if ($k =~ m/^XDG_/) {
   unless ($k =~ m/^XDG_RUNTIME_DIR$/) {
    $lnx++;
   } # unless
  } # if
 } # foreach
}

if (defined($ENV{'GTK_IM_MODULE'}) || defined($ENV{'QT_IM_MODULE'})) {
 $lnx+=5;
}
if (defined($ENV{'XMODIFIERS'})) {
 $lnx+=5;
}

my $max = max ($win, $wsl, $mac, $lnx);

# report results
print STDOUT "WIN $win, WSL: $wsl, MAC: $mac, LNX: $lnx\n";
print STDOUT "MAX $max, ERR: " . $? . "\n";

#if ($win == $max) {
# system ("start http://localhost:8765/");
#} elsif (($wsl == $max || $lnx == $max)  && -f "/usr/bin/xdg-open") {
# system ("xdg-open http://localhost:8765/");
#} elsif ($mac == $max && -f "/usr/bin/open") {
# system ("open http://localhost:8765/");
#}

