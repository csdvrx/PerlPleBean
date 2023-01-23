#!/usr/bin/perl

use strict;
use warnings;
use Net::DNS::Nameserver;

sub reply_handler {
    my ( $qname, $qclass, $qtype, $peerhost, $query, $conn ) = @_;
    my ( $rcode, @ans, @auth, @add );

    # First: general discovery
    # for use with: dns-sd  -B  _services._dns-sd._udp  local.
    if ( $qclass eq "IN" && $qtype eq "PTR" && $qname eq "_services._dns-sd._udp.local" ) {
            print "##### 1st query (PTR _services._dns-sd._udp.local) is matching, preparing reply = 1x PTR #####\n";
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            #my $ptr = Net::DNS::RR->new("qname ttl qtype target");
            my $ptr = Net::DNS::RR->new("_services._dns-sd._udp.local $ttl PTR _http._tcp.local.");
            push @ans, $ptr;
            #my $ptr2 = Net::DNS::RR->new("_http._tcp.local $ttl PTR PerlPleBean._http._tcp.local.");
            #push @ans, $ptr2;
            #my $priority=0;
            #my $weight=0;
            #my $port=8765;
            ##my srv = Net::DNS::RR->new('name SRV priority weight port target');
            #my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port localhost.");
            #push @ans, $srv;
            $rcode = "NOERROR";
    # Second: respond to http service discovery
    # for use with: dns-sd -B _http._tcp local.
    #
    # NOT: dns-sd -B PerlPleBean._http._tcp local.
    # OTHERWISE ASKS: PerlPleBean._sub._http._tcp.local
    } elsif ( $qclass eq "IN" && $qtype eq "PTR" && $qname eq "_http._tcp.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            print "##### 2nd query (PTR _http._tcp.local) is matching, preparing reply = 1x PTR + 1x SRV + 1x A #####\n";
            my $ptr = Net::DNS::RR->new("_http._tcp.local $ttl PTR PerlPleBean._http._tcp.local.");
            push @ans, $ptr;
            $rcode = "NOERROR";
    # In theory with 2 records, SRV and PTR, along with an optional TXT
    # according to "Publication: An Example" figure 4.1 of https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/NetServicesArchitecture.html#//apple_ref/doc/uid/20001074-SW1
    # However, not seen in tcpdump, more like piecewise queries and replies
    # More like "Discovery" figure 4.2 of https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/NetServicesArchitecture.html#//apple_ref/doc/uid/20001074-SW1
    # But seems required?
            if (1) {
             my $priority=0;
             my $weight=0;
             my $port=8765;
             my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port 4.lo.perlplebean.local.");
             push @ans, $srv;
             $rcode = "NOERROR";
             # FIXME: doesn't seem to work, could try with a CNAME or a glue record?
             my $a =  Net::DNS::RR->new("4.lo.perlplebean.local. $ttl A 127.0.0.4");
             push @ans, $a;
            my $a2 = Net::DNS::RR->new(
        owner   => 'lo.perlpleean.local',
        ttl     => 5,
        class   => 'IN',
        type    => 'A',
        address => '127.0.0.2'
        );
            }
            if (0) {
             # FIXME: is it possible to use a .local address if adding a A record to 127/8?
             # idea: do like https://kops.uni-konstanz.de/bitstream/handle/123456789/36582/Kaiser_0-375333.pdf;jsessionid=3488F3DE83C8AE5D3462EEC87C28FBB6?sequence=3
             # for an in-bailiwick subdomain, publish NS and A records for a to do scoped service discovery
             # by first sending a query about NS, then its answer with NS a A records:
             # "The programming query answer’s sole purpose is to make the cache name server store the NS entries"
             # so would be like _services._dns-sd._udp but on a special domain - so which one?
             # RFC6761: "Caching DNS servers SHOULD recognize .test. names as special and SHOULD NOT, by default, attempt to look up NS records for them" (likewise for .localhost.) => but programming query could do the trick?
             # RFC6762: "Any DNS query for a name ending with .local. MUST be sent to the mDNS IPv4 link-local multicast address 224.0.0.251 (or its IPv6 equivalent FF02::FB" => in the worst case, use .local.
             # RFC1918 reserves private IP ranges 10/8 172.16/12 192.168/16 : do multihomed with 127/8 and link-local too
             #print "Trying to add a A record\n";
             #my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port localhost.");
             #push @ans, $srv;
            }
    } elsif ( $qclass eq "IN" && $qtype eq "SRV" && $qname eq "PerlPleBean._http._tcp.local" ) {
            print "##### 3nd query is matching (SRV PerlPleBean._http._tcp.local), preparing reply = 1x SRV #####\n";
            my $priority=0;
            my $weight=0;
            my $port=8765;
            my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port perlplebean.local.");
            push @ans, $srv;
            $rcode = "NOERROR";
    } elsif ( $qclass eq "IN" && $qtype eq "A" && $qname eq "perlplebean.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            print "##### 4th query is matching (A perlplebean.local), preparing reply = 1x A #####\n";
            #my $a = Net::DNS::RR->new(
            #owner   => 'host.example.com',
            #ttl     => 5,
            #class   => 'IN',
            #type    => 'A',
            #address => '127.0.0.222'
            #);
            my $a = Net::DNS::RR->new("perlplebean.local. $ttl A 127.0.0.20");
            push @ans, $a;
            $rcode = "NOERROR";
            # FIXME: borked? corrupt wire-format data at Net/DNS/Question.pm line 112.
            # due to decode:
            # ( $self->{qname}, $offset ) = Net::DNS::DomainName1035->decode(@_);
            # my $next = $offset + QFIXEDSZ;
            # length $$data < $next;
    } elsif ( $qclass eq "IN" && $qtype eq "AAAA" && $qname eq "perlplebean.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            print "##### 5th query is matching (AAAA perlplebean.local), preparing NXDOMAIN reply = 1x AAAA #####\n";
            # May want to claim a private IPv6 address, but while IPv4 offers a lot of space in 127/8
            # IPv6 only offers 1 loopback address ::1 (!!!)
            # Before, it has fec0::/10 for site-local address precedence 1, but deprecated by rfc3879
            # Could use instead fc00::/7 unique-local address even if precedence 3, but requires ifup
            # May have to do with link local unicast fe80::/64 but would suck as much as 169.254/16
            # TLDR: IPv6 has nothing as good (ie not requiring ifup) and as roomy (for random alloc) as IPv4 loopback
            my $aaaa = Net::DNS::RR->new("perlplebean.local. $ttl AAAA ::1");
            # The best move seems to be not to play, so be IPv6 incompatible: fail
            # because ::1 would bring back port sharing issues (would have to multiplex port 80 and 443)
            # that 127/8 avoids (2^24 =~> 16M apps could each claim port 80 and 443 at the same time)
            #$rcode = "NOERROR";
            #$rcode = "SERVFAIL";
            $rcode = "NXDOMAIN";
            push @ans, $aaaa;
    } elsif ( $qclass eq "IN" && $qtype eq "TXT" && $qname eq "PerlPleBean._http._tcp.local" ) {
            print "##### last and optional query is matching (TXT PerlPleBean._http._tcp.local), preparing reply = 1 TXT #####\n";
            my $txt = Net::DNS::RR->new("PerlPleBean._http._tcp.local TXT PurpleBean.local.");
            push @ans, $txt;
            $rcode = "NOERROR";
    } elsif ( $qclass eq "IN" && $qtype eq "A" && $qname eq "PerlPleBean._http._tcp.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            print "##### CUSTOM 1 query is matching (A PerlPleBean._http._tcp.local), preparing reply = 2 A #####\n";
            my $a1 = Net::DNS::RR->new("PerlPleBean._http._tcp.local $ttl A 127.0.0.10");
            push @ans, $a1;
            # Goal: get a .local, .localhost or .test domain
            # FIXME: doesn't seem to work, could try with a CNAME or a glue record?
            my $a2 =  Net::DNS::RR->new("perlplebean.local. $ttl A 127.0.0.11");
            push @ans, $a2;
            $rcode = "NOERROR";
    } elsif ( $qname eq "_http._tcp.local" ) {
            $rcode = "NXDOMAIN";
    } else {
    #  Keep an eye on to notice spurious requests than could interfere, like
    #  _microsoft_mcc._tcp.local IN PTR
            print "##### Received unknown query from $peerhost to " . $conn->{sockhost} . " #####\n";
            #$query->print;
            print "qname=$qname, qclass=$qclass, qtype=$qtype, peerhost=$peerhost\n";
            #$rcode = "NXDOMAIN";
            $rcode = "SERVFAIL";
    }

    # mark the answer as authoritative by setting the 'aa' flag?
    my $headermask = {aa => 1};
    # FIXME: should only be required when stuffing A, NS or CNAMES
    #my $headermask = {};

    # specify EDNS options as { option => value } ?
    my $optionmask = {};

    # FIXME: ideally, would reply just for what's handled, not sure how to do that
    #if ($rcode eq "NOERROR") {
     return ( $rcode, \@ans, \@auth, \@add, $headermask, $optionmask );
    #} else {
    #  return (0);
    #}
}


my $ns = Net::DNS::Nameserver->new(
    # LocalAddr    => "127.0.0.1",
    MCastAddr    => "224.0.0.251",
    # FIXME: should have a MCastTTL option instead of hardcoding 2
    # FIXME: should also have a MCastReplyTo option instead of hardcoding replying to both
    LocalPort    => 5353,
    ReplyHandler => \&reply_handler,
    Verbose      => 0
    ) || die "couldn't create nameserver object\n";


# Since this gets stuck on the main loop, may require forking
$ns->main_loop;

