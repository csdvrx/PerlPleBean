#!/usr/bin/perl

use strict;
use warnings;
use Net::DNS::Nameserver;

sub reply_handler {
    my ( $qname, $qclass, $qtype, $peerhost, $query, $conn ) = @_;
    my ( $rcode, @ans, @auth, @add );

    # First: respond to general discovery with 2 PTR and 1 SRV
    # 20:25:04.676871 IP 172.22.160.183.5353 > 224.0.0.251.5353: 0 PTR (QM)? _services._dns-sd._udp.local. (46)
    # 20:25:04.677530 IP 172.22.160.1.5353 > 224.0.0.251.5353: 0*- [0q] 1/0/0 PTR _http._tcp.local. (65)
    #
    # for use with: dns-sd  -B  _services._dns-sd._udp  local.
    if ( $qclass eq "IN" && $qtype eq "PTR" && $qname eq "_services._dns-sd._udp.local" ) {
            print "##### 1st query is matching, preparing reply = 2 PTR + 1 SRV #####\n";
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            #my $ptr = Net::DNS::RR->new("qname ttl qtype target");
            my $ptr1 = Net::DNS::RR->new("_services._dns-sd._udp.local $ttl PTR _http._tcp.local.");
            push @ans, $ptr1;
            my $ptr2 = Net::DNS::RR->new("_http._tcp.local $ttl PTR PerlPleBean._http._tcp.local.");
            push @ans, $ptr2;
            my $priority=0;
            my $weight=0;
            my $port=8765;
            #my srv = Net::DNS::RR->new('name SRV priority weight port target');
            my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port localhost.");
            push @ans, $srv;
            $rcode = "NOERROR";
    # for use with: dns-sd -B _http._tcp local.
    # if: dns-sd -B PerlPleBean._http._tcp local.
    # then: PerlPleBean._sub._http._tcp.local
    #
    # Second: respond to service discovery with 2 records, SRV and PTR, along with an optional TXT
    # according to "Publication: An Example" figure 4.1 of https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/NetServicesArchitecture.html#//apple_ref/doc/uid/20001074-SW1
    # However, SRV not seen in tcpdump or in the wildcard below:
    # 20:25:04.677625 IP 172.22.160.183.5353 > 224.0.0.251.5353: 0 PTR (QM)? _http._tcp.local. (34)
    # 20:25:04.789256 IP 172.22.160.1.5353 > 224.0.0.251.5353: 0*- [0q] 1/0/6 PTR PerlPleBean._http._tcp.local. (178)
    # More like "Discovery" figure 4.2 of https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/NetServicesArchitecture.html#//apple_ref/doc/uid/20001074-SW1
    } elsif ( $qclass eq "IN" && $qtype eq "PTR" && $qname eq "_http._tcp.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            my $priority=0;
            my $weight=0;
            my $port=8765;
            print "##### 2nd query is matching, preparing reply = 1 PTR + 1 SRV + 1 TXT #####\n";
            my $ptr = Net::DNS::RR->new("_http._tcp.local $ttl PTR PerlPleBean._http._tcp.local.");
            push @ans, $ptr;
            unless (1) {
             # FIXME: is it possible to use a .local address if adding a A record to 127/8?
             # idea: do like https://kops.uni-konstanz.de/bitstream/handle/123456789/36582/Kaiser_0-375333.pdf;jsessionid=3488F3DE83C8AE5D3462EEC87C28FBB6?sequence=3
             # for an in-bailiwick subdomain, publish NS and A records for a to do scoped service discovery
             # by first sending a query about NS, then its answer with NS a A records:
             # "The programming query answer’s sole purpose is to make the cache name server store the NS entries"
             # so would be like _services._dns-sd._udp but on a special domain - so which one?
             # RFC6761: "Caching DNS servers SHOULD recognize .test. names as special and SHOULD NOT, by default, attempt to look up NS records for them" (likewise for .localhost.) => but programming query could do the trick?
             # RFC6762: "Any DNS query for a name ending with .local. MUST be sent to the mDNS IPv4 link-local multicast address 224.0.0.251 (or its IPv6 equivalent FF02::FB" => in the worst case, use .local.
             # RFC1918 reserves private IP ranges 10/8 172.16/12 192.168/16 : do multihomed with 127/8 and link-local too
             print "Trying to add a A record\n";
             #my srv = Net::DNS::RR->new('name SRV priority weight port target');
             my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port localhost.");
             push @ans, $srv;
            } else {
             my $srv = Net::DNS::RR->new("PerlPleBean._http._tcp.local SRV $priority $weight $port perlplebean.local.");
             push @ans, $srv;
             # FIXME: doesn't seem to work, could try with a CNAME or a glue record?
             my $a =  Net::DNS::RR->new("perlplebean.local. $ttl A 127.0.0.2");
             push @ans, $a;
            }

            # The optional TXT
            #my $txt = Net::DNS::RR->new('name TXT txtdata ...');
            my $txt = Net::DNS::RR->new("PerlPleBean._http._tcp.local TXT PurpleBean.local.");
            push @ans, $txt;
            $rcode = "NOERROR";
    } elsif ( $qclass eq "IN" && $qtype eq "A" && $qname eq "PerlPleBean._http._tcp.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            print "##### 3nd query is matching, preparing reply = 2 A + 1 TXT #####\n";
            my $a1 = Net::DNS::RR->new("PerlPleBean._http._tcp.local $ttl A 127.0.0.2");
            push @ans, $a1;
            # Goal: get a .local, .localhost or .test domain
            # FIXME: doesn't seem to work, could try with a CNAME or a glue record?
            my $a2 =  Net::DNS::RR->new("perlplebean.local. $ttl A 127.0.0.2");
            push @ans, $a2;
            # The optional TXT
            #my $txt = Net::DNS::RR->new('name TXT txtdata ...');
            my $txt = Net::DNS::RR->new("PerlPleBean._http._tcp.local TXT PurpleBean.local.");
            #push @ans, $txt;
            $rcode = "NOERROR";
    } elsif ( $qclass eq "IN" && $qtype eq "A" && $qname eq "perlplebean.local" ) {
            my $ttl=5; # if no further reply 4*ttl~=20s after the initial reply, will remove the entry
            print "##### 4nd query is matching, preparing reply = 1 A #####\n";
            my $a1 = Net::DNS::RR->new("perlplebean.local. $ttl A 127.0.0.2");
            my $a2 = Net::DNS::RR->new("perlplebean.local. $ttl IN CNAME 4lo.perlplebean.local");
            my $a3 = Net::DNS::RR->new("4lo.perlplebean.local. $ttl IN A 127.0.0.2");
            # FIXME: borked? corrupt wire-format data at Net/DNS/Question.pm line 112.
            # due to decode:
            # ( $self->{qname}, $offset ) = Net::DNS::DomainName1035->decode(@_);
            # my $next = $offset + QFIXEDSZ;
            # length $$data < $next;
            my $a = Net::DNS::RR->new(
        owner   => 'host.example.com',
        ttl     => 5,
        class   => 'IN',
        type    => 'A',
        address => '127.0.0.7'
        );
            push @ans, $a1;
            push @ans, $a2;

            $rcode = "NOERROR";
    } elsif ( $qname eq "_http._tcp.local" ) {
            $rcode = "NXDOMAIN";
    } else {
    #  Keep an eye on to notice spurious requests than could interfere, like
    #  _microsoft_mcc._tcp.local IN PTR
            print "##### Received unknown query from $peerhost to " . $conn->{sockhost} . " #####\n";
            #$query->print;
            print "qname=$qname, qclass=$qclass, qtype=$qtype, peerhost=$peerhost, query=$query, conn=$conn\n";
            #$rcode = "NXDOMAIN";
            $rcode = "SERVFAIL";
    }

    # mark the answer as authoritative by setting the 'aa' flag?
    my $headermask = {aa => 1};
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
    LocalPort    => 5353,
    ReplyHandler => \&reply_handler,
    Verbose      => 1
    ) || die "couldn't create nameserver object\n";


# Since this gets stuck on the main loop, may require forking
$ns->main_loop;

