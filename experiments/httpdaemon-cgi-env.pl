#!/usr/bin/perl -w
 use strict;
 use HTTP::Daemon;
 use CGI 2.50 qw/:standard :cgi-lib/;

 my $d = HTTP::Daemon->new || die;
 print "Please contact me at: <URL:", $d->url, ">\n";
 while (my $c = $d->accept) {
     while (my $r = $c->get_request) {

       my $form_parameters;
       if ( $r->uri =~ /\?/ ) {
         $form_parameters = $r->uri;
         $form_parameters =~ s/[^\?]+\?(.*)/$1/;
       } else { $form_parameters = $r->content; }
       $CGI::Q = new CGI($form_parameters);

       my $param = param("hello");
       print "Content-type: text/plain\n\n";
       print "I saw: $param\n";
       use Data::Dumper;
       print Dumper(\%ENV);

     }
     $c->close;
     undef($c);
 }
