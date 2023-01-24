#!/usr/bin/perl
use strict;
use warnings;
use Net::DNS::Nameserver;

# Where we live
my $bonjour_localport=5353;
my $bonjour_mcastaddr="224.0.0.251";
#my $bonjour_mcastaaaa="ff02::fb"; # FIXME: add that to Nameserver.pm
# What we reply with:
my $bonjour_http_port=3210;
#my $bojour_httpsport=9999; # TODO: add https and letsencrypt

# TODO: add multihoming
#  - on the LAN with pseudo DHCP and SLAAC request to claim IPs
#  - on the WAN with UPNP firewall hole-punching by asking nicely
# Could get started by grabbing a dozen LAN IPs and as many holes to assign as needed later

# Hash of the 127/8 IP attribution by .local domains
my %domain_to_ipv6;
my %domain_to_ipv4;

# That means domains WITHOUT trailing dot of FQDN, added by the handler as needed

# For test, with explicits (and unnecessary) undefs, and SERVFAIL to issue failures
$domain_to_ipv6{'test.local'}            =undef;
$domain_to_ipv4{'test.local'}            ="127.1.2.7";
$domain_to_ipv6{'fail.local'}            ="SERVFAIL";
$domain_to_ipv4{'fail.local'}            ="SERVFAIL";
$domain_to_ipv6{'sick.local'}            ="NXDOMAIN";
$domain_to_ipv4{'fail.local'}            ="SERVFAIL";
$domain_to_ipv4{'ipv6only.local'}        =undef;
$domain_to_ipv4{'ipv6only.local'}        ="::1";
$domain_to_ipv4{'ipv4only.local'}        ="127.127.127.127";
$domain_to_ipv4{'ipv4only.local'}        =undef;

# WONTFIX: if you use 127.0.0.1, your reverse will fail if /etc/hosts has entries like:
# 127.0.0.1       kubernetes.docker.internal
# So instead, make yourself at home on 127/8 by picking... about anything else!

# For actual use
$domain_to_ipv6{'perlplebean.local'}     ="::1";
$domain_to_ipv4{'perlplebean.local'}     ="127.6.5.4";
#$domain_to_ipv4{'perlplebean.local'}    ="127.2.2.1"; # why not?
# Weird experiments with packing records to see "what if..."
$domain_to_ipv4{'lo.perlplebean.local'}  ="127.2.2.2";
$domain_to_ipv4{'lol.perlplebean.local'} ="127.2.2.3";
$domain_to_ipv4{'4.lo.perlplebean.local'}="127.2.2.4";

# Apps will each have their own domain, and a place to control that
# like xinetd, maybe with letsencrypt issue certificates
# and a reverse watchdog able to start on-deman memory-hungry apps
# using the 4x TTL trick, and monitoring requests/memory use etc.
$domain_to_ipv4{'apps.local'}            ="127.3.2.1";
$domain_to_ipv6{'apps.local'}            ="::1";
# These would be the always on services
$domain_to_ipv4{'spreadsheet.local'}     ="127.3.2.2";
$domain_to_ipv6{'spreadsheet.local'}     ="::1";
$domain_to_ipv4{'database.local'}        ="127.3.2.3";
$domain_to_ipv6{'database.local'}        ="::1";
$domain_to_ipv4{'files.local'}           ="127.3.2.4";
$domain_to_ipv6{'files.local'}           ="::1";
$domain_to_ipv4{'text.local'}            ="127.3.2.5";
$domain_to_ipv6{'text.local'}            ="::1";
$domain_to_ipv4{'vim.local'}             ="127.3.2.6";
$domain_to_ipv6{'vim.local'}             ="::1";
# TODO: should add ssh.local with SSHFP records, xterm.local with PTY etc

# FIXME: I hate all these ::1 because it's ugly
# But limit of IPv6: we don't have something as large as 127/8 defaulting to UP without ifconfig
# May want to claim a private IPv6 address, but while IPv4 offers a lot of space in 127/8
# IPv6 is stingy: itonly offers 1 loopback address ::1 (!!!)
# Before, it had fec0::/10 for site-local address precedence 1, but deprecated by RFC3879
# Could use instead fc00::/7 unique-local address even if precedence 3, but requires ifup/ifconfig
# May have to do with link local unicast fe80::/64 but would suck as much as 169.254/16
# and it would require managing them on each interface... while loopback is about avoiding that
# (at least until we get into multihoming)
# But IPv6 has nothing as good (not requiring ifup) and as roomy (for random alloc) as IPv4 loopback 127/8
# The best move seems to be not to play, so be IPv4 only and issue SERVFAIL if there's no simple solution
# because ::1 would bring back the port sharing issues (would have to multiplex port 80 and 443)
# that 127/8 avoids (2^24 =~> 16M apps could each claim port 80 and 443 at the same time easy peasy)

# Reverse the above
my %reverse_ipv4;
foreach my $k (keys %domain_to_ipv4) {
  my $v= $domain_to_ipv4{$k};
  # no trailing dot either, added by the handler as needed
  if (defined($v)) {
   my @part=split(/\./, $v);
   if (scalar(@part)==4) {
    $reverse_ipv4{"$part[3].$part[2].$part[1].$part[0].in-addr.arpa.local"}=$k;
   }
  }
}
# FIXME: add the IPv6 equivalent
#use Data::Dumper;
#print Dumper($reverse_ipv4{'6.2.3.127.in-addr.arpa.local'});

# Bonjour needs query type 1,2,3
# ping and browsers need query type 4,5,6,7
sub reply_handler {
 my ( $qname, $qclass, $qtype, $peerhost, $query, $conn ) = @_;
 my ( $rcode, @ans, @auth, @add );
 my $ttl=30; # if no further reply about 4*ttl after the initial reply, will remove the entry
 my $authoritative=0;
 ############################################################################
 # This is mostly BonjourSD: Apple specific stuff not needed for regular use
 ############################################################################
 # WARNING: Should be fully qualified by RFC1034, but in tests it wasn't observed for queries type 1,2,3
 # it may require more investigation like for exampl there's no final not cf RFC2822 and RFC5322 #3.4.1 #3.2.3
 # as it may be as confusing as final dots can be for http virtual host
 my $bonjoursd_rfc1034=".";
 if ( $qclass eq "IN" && $qtype eq "PTR" && $qname eq "_services._dns-sd._udp.local" ) {
  # general discovery, for use with: dns-sd  -B  _services._dns-sd._udp local.
  print "##### 1st $qclass query ($qtype $qname): reply = 1x PTR NOERROR\n";
  # FIXME: should show the actual reply, DUH! Either by decoding @ans or by simply printing more as needed
  #print "##### 1st $qclass query ($qtype $qname): ";
  my $ptr = Net::DNS::RR->new("$qname$bonjoursd_rfc1034 $ttl $qtype _http._tcp.local.");
  push @ans, $ptr;
  $rcode = "NOERROR";
  #print "PTR=_http._tcp.local $rcode\n";
  if (0) {
   # FIXED: it seems useless to pack extra stuff to try to anticipate the 2nd and 3rd queries
   print "Trying to anticipate step2 and step3 with extra PTR and A records\n";
   my $ptr2 = Net::DNS::RR->new("_http._tcp.local $ttl PTR PerlPleBean._http._tcp.local.");
   push @ans, $ptr2;
   my $priority=0;
   my $weight=0;
   my $srv3 = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $bonjour_http_port perlplebean.local.");
   push @ans, $srv3;
  }
 } elsif ( $qclass eq "IN" && $qtype eq "PTR" && $qname eq "_http._tcp.local" ) {
  # respond to http service discovery, for use with: dns-sd -B _http._tcp local.
  #            NOT: dns-sd -B PerlPleBean._http._tcp local.
  # OTHERWISE ASKS: PerlPleBean._sub._http._tcp.local
  print "##### 2nd $qclass query ($qtype $qname): reply = 1x PTR + 1x SRV + 1x A NOERROR\n";
  my $ptr = Net::DNS::RR->new("$qname$bonjoursd_rfc1034 $ttl $qtype PerlPleBean.$qname.");
  push @ans, $ptr;
  $rcode = "NOERROR";
  # In theory with 2 records, SRV and PTR, along with an optional TXT
  # according to "Publication: An Example" figure 4.1 of https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/NetServicesArchitecture.html#//apple_ref/doc/uid/20001074-SW1
  # However, not seen in tcpdump: it's more like piecewise queries and replies
  # More like "Discovery" figure 4.2 of https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/NetServicesArchitecture.html#//apple_ref/doc/uid/20001074-SW1
  # Yet this seems required?
  if (1) { # FIXED: yes it is
   # It can be easily tested with if (0) and seing which of that or the reply from the 3rd query below is used
   print "Trying to add SRV and A\n";
   my $priority=0;
   my $weight=0;
   my $srv3 = Net::DNS::RR->new("PerlPleBean.$qname$bonjoursd_rfc1034 SRV $priority $weight $bonjour_http_port 4.lo.perlplebean.local.");
   push @ans, $srv3;
   # If we pack the reply with extra stuff, will it be used?
   # FIXME: doesn't seem to work, could we try with a CNAME, a glue record etc?
   my $a4 =  Net::DNS::RR->new("4.lo.perlplebean.local$bonjoursd_rfc1034 $ttl A $domain_to_ipv4{'4.lo.perlplebean.local'}");
   push @ans, $a4;
   if (0) {
    # FIXME: what about adding extra extra stuff? will it be cached?
    print "Trying to add a spurious A record for lol\n";
    my $a4lol = Net::DNS::RR->new(
     owner   => 'lol.perlpleean.local',
     ttl     => 5,
     class   => 'IN',
     type    => 'A',
     address => $domain_to_ipv4{'lol.perlplebean.local'}
    );
    push @ans, $a4lol;
   }
  } else {
   print "SRV and A were NOT added which may break things\n";
  }
  # FIXED: it seems we can't anticipate the 3rd step
  if (0) {
   print "Trying to anticipate step3 with an extra A record\n";
   my $priority=0;
   my $weight=0;
   my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $bonjour_http_port localhost.");
   push @ans, $srv;
  }
 } elsif ( $qclass eq "IN" && $qtype eq "SRV" && $qname eq "PerlPleBean._http._tcp.local" ) {
  print "##### 3nd $qclass query ($qtype $qname), reply = 1x SRV NOERROR\n";
  my $priority=0;
  my $weight=0;
  my $srv = Net::DNS::RR->new("$qname. $qtype $priority $weight $bonjour_http_port perlplebean.local$bonjoursd_rfc1034");
  push @ans, $srv;
  $rcode = "NOERROR";

  ############################################################################
  # This is where important stuff is (ping, etc): the above is Apple specific
  ############################################################################

  # FIXME: is it possible to have subdomains in .local just by adding more records to 127/8?
  # What about other special domains like .test? Can their unique features be leveraged?
  # Can we get not just a .local, but maybe also a .localhost or .test domain? Why? Why not!
  # RFC6761: "Caching DNS servers SHOULD recognize .test. names as special and SHOULD NOT, by default, attempt to look up NS records for them" (likewise for .localhost.) => but programming query could do the trick? What about non NS?
  # RFC6762: "Any DNS query for a name ending with .local. MUST be sent to the mDNS IPv4 link-local multicast address 224.0.0.251 (or its IPv6 equivalent FF02::FB" => in the worst case, we can safely stick to .local.
  # RFC1918 reserves private IP ranges 10/8 172.16/12 192.168/16 could do multihomed with 127/8 and link-local too
  #
  # Idea: do like https://kops.uni-konstanz.de/bitstream/handle/123456789/36582/Kaiser_0-375333.pdf
  # for an in-bailiwick subdomain, publish NS and A records for a to do scoped service discovery
  # by first sending a query about NS, and stuff its answer with NS a A records:
  # "The programming query answer’s sole purpose is to make the cache name server store the NS entries"
  # so would be like _services._dns-sd._udp but on a special domain - so which one? any?
  # Can we be more surgical and hijack a default PTR query to do the job?
  # There seems to be quite a few in the wild:
  #  windows=_microsoft_mcc._tcp.local
  #  apple  =_sleep-proxy._udp.local
  #  android= _googlecast._tcp.local
 } elsif ( $qclass eq "IN" && $qtype eq "A" && defined($domain_to_ipv4{$qname})) {
  # Yes, I made it so that the 4th type would be the A record for IPv4
  print "##### 4th $qclass query ($qtype $qname), reply = 1x A NOERROR AUTHORITATIVE\n";
  # Yeah I'm like totally legit, trust me bro because I said so
  $authoritative=1;
  # And this reply is NOT ignored but actually used lol
  my $a = Net::DNS::RR->new("$qname. $ttl $qtype $domain_to_ipv4{$qname}");
  push @ans, $a;
  if ($domain_to_ipv4{$qname}=~ m/SERVFAIL/) {
   # Play dead
   $rcode = "SERVFAIL";
  } elsif ($domain_to_ipv4{$qname}=~ m/NXDOMAIN/) {
   # The dog ate my homework
   $rcode = "NXDOMAIN";
  } else {
   $rcode = "NOERROR";
  }
 } elsif ( $qclass eq "IN" && $qtype eq "PTR" && defined($reverse_ipv4{$qname})) {
  print "##### 5th $qclass query ($qtype $qname) reply = 1x PTR NOERROR AUTHORITATIVE\n";
  # OMG we're sooo authoritative that we're asked the reverse!
  # Let's keep playing along, because of course we're like totally legit, amirite?
  $authoritative=1;
  # legit af I'm telling you, now please believe this at least for a minute
  our $ttl=60; # HINT: 'our' is like 'local' but for functions instead of packages
  # 'our' is for localized lexical scoping, while 'local' for the global namespace scope of package variables
  my $ptr = Net::DNS::RR->new("$qname $ttl $qtype $reverse_ipv4{$qname}"); # FIXME: is a trailing dot needed?
  # FIXME: dig -x was working before, wtf did I do to break it during a refactoring
  # FIXME: maybe adding a test suite would be a good idea BTW
  push @ans, $ptr;
  if ($reverse_ipv4{$qname}=~ m/SERVFAIL/) {
   # Play dead
   $rcode = "SERVFAIL";
  } elsif ($reverse_ipv4{$qname}=~ m/NXDOMAIN/) {
   # The dog ate my homework
   $rcode = "NXDOMAIN";
  } else {
   $rcode = "NOERROR";
  }
 } elsif ( $qclass eq "IN" && $qtype eq "AAAA" && defined($domain_to_ipv6{$qname})) {
  # Yes, I made it so that the 6th type would be the AAAA record for IPv6
  print "##### 6th $qclass query ($qtype $qname), rely = 1x AAAA SERVFAIL AUTHORITATIVE\n";
  $authoritative=1;
  my $aaaa = Net::DNS::RR->new("$qname. $ttl $qtype $domain_to_ipv6{$qname}");
  if ($domain_to_ipv6{$qname}=~ m/SERVFAIL/) {
   # Play dead
   $rcode = "SERVFAIL";
  } elsif ($domain_to_ipv6{$qname}=~ m/NXDOMAIN/) {
   # The dog ate my homework
   $rcode = "NXDOMAIN";
  } else {
   $rcode = "NOERROR";
  }
  push @ans, $aaaa;
  ############################################################################
  # This seems optional but done not just by Apple and Bonjour, so we keep it
  ############################################################################
 } elsif ( $qclass eq "IN" && $qtype eq "TXT" && $qname eq "PerlPleBean._http._tcp.local" ) {
  print "##### 7th query ($qtype $qname), reply = 1 TXT NOERROR\n";
  my $txt = Net::DNS::RR->new("$qname $qtype PurpleBean.local.");
  push @ans, $txt;
  $rcode = "NOERROR";

  # TODO: maybe we should handle CNAMEs, NS etc.
  # How it's done will depend on how subdomains experiments go and what is achievable

  ############################################################################
  # This is were weird experiments starts: can the Finder get an icons/links?
  ############################################################################
 } elsif ( $qclass eq "IN" && $qtype eq "A" && $qname eq "PerlPleBean._http._tcp.local" ) {
  # I have no idea what I'm doing lol
  print "##### CUSTOM1 query ($qtype $qname), reply = 2 A NOERROR #####\n";
  # FIXME should add record type to %domain_to_ipv4_type_override even if just for custom tests
  # like $domain_to_ipv4_type_override{"perlplebean.local"}{"A"}="127.0.0.11";
  my $a1 = Net::DNS::RR->new("$qname $ttl $qtype 127.0.0.10");
  push @ans, $a1;
  # FIXME: doesn't seem to work, could try packing it more, like with a CNAME or a glue record?
  my $a2 =  Net::DNS::RR->new("perlplebean.local. $ttl A 127.0.0.11");
  push @ans, $a2;
  $rcode = "NOERROR";
  ############################################################################
  # This shows what's happening on mDNS multicast 5353: I didn't see much yet
  ############################################################################
 } elsif ( $qname eq "_http._tcp.local" ) {
  print "##### bad query ($qtype $qname), reply = NXDOMAIN even if we should NOT reply FIXME\n"; # FIXME indeed
  # FIXME: Because yes, ideally, we shouldn't even reply
  $rcode = "NXDOMAIN";
  ############################################################################
  # This is a catchall for the unhandled case. WIP: ideally wouldn't interfere
  ############################################################################
 } else {
    #  Useful to keep an eye on to notice the spurious requests that we could want to hijack/interfere with, like:
    #  CLASS32769 _microsoft_mcc._tcp.local
    #  PTR _googlecast._tcp.local
    #  PTR _sleep-proxy._udp.local
    print "##### unknown $qclass query ($qtype $qname) from $peerhost to " . $conn->{sockhost} . " #####\n";
    #$query->print;
    #$rcode = "unknown";
    # FIXME: it'd be better to stay silent
    $rcode = "SERVFAIL";
 }
 # mark the answer as authoritative by setting the 'aa' flag?
 my $headermask = {aa => $authoritative};

 # specify EDNS options as { option => value } ?
 my $optionmask = {};

 # FIXME: ideally, would reply just for what's handled to avoid too much interference
 #unless ($rcode eq "unknown") {
  return ( $rcode, \@ans, \@auth, \@add, $headermask, $optionmask );
 #} else {
 # return (0);
 #}
}

my $ns = Net::DNS::Nameserver->new(
# FIXME: should pass a hash of localaddr to impersonate things as needed
# by settings UDP sockets for the 127/8
 # LocalAddr    => "$bonjour_localaddr",
# FIXME: should also have MCastAddrIPv6 using $bonjour_mcastaaaa
 MCastAddr    => $bonjour_mcastaddr,
 # FIXME: should consider a MCastDefaultTTL option instead of hardcoding 2
 # FIXME: should also have a MCastReplyTo option instead of hardcoding replying to both
 LocalPort    => $bonjour_localport,
 ReplyHandler => \&reply_handler,
 Verbose      => 0
) || die "$0: couldn't create nameserver object\n";


# Since this gets stuck on the main loop, may require forking
$ns->main_loop;

