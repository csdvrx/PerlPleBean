 #!/usr/bin/perl
 use strict;
 use warnings;
 use HTTP::Daemon;
 use IO::String;
 use CGI 2.50 qw/:standard :cgi-lib/;

 my $d = HTTP::Daemon->new(Reuse=>1,LocalPort=>6969) || die;
 print "Please contact me at: <URL:", $d->url, ">\n";

 while (my $c = $d->accept) {
     while (my $r = $c->get_request) {

       # environs that a webserver should set.
       $ENV{'REQUEST_METHOD'}    = $r->method;
       $ENV{'GATEWAY_INTERFACE'} = "CGI/1.0";
       $ENV{'SERVER_PROTOCOL'}   = $r->protocol;
       $ENV{'CONTENT_TYPE'}      = $r->content_type;

       my $form_parameters; # GET/POST storage.

       # is this a happy GET?
       if ( $r->uri =~ /\?/ ) {
         $form_parameters = $r->uri;
         $form_parameters =~ s/[^\?]+\?(.*)/$1/;
         $CGI::Q = new CGI($form_parameters);
       }

       # possibly POST?
       else {

         # now decide how we want to turn the parameters
         # over to CGI.pm. note that this will cause
         # problems with your STDIN with multipart forms.
         my $form_parameters = $r->content;
         $ENV{'CONTENT_LENGTH'} = $r->content_length;

         # sounds like multipart.
         if ($form_parameters =~ /^--/) {

           my ($boundary) = split(/\n/, $form_parameters); chop($boundary);
           substr($boundary, 0, 2) = ''; # delete the leading "--" !!!
           $ENV{'CONTENT_TYPE'} = $r->content_type . "; boundary=$boundary";

           # this breaks STDIN forever. I've yet to discover
           # how to properly save and reassign STDIN after
           # we're done breaking things horrifically here.
           close STDIN; my $t = tie *STDIN, 'IO::String';
           $t->open($form_parameters); $CGI::Q = new CGI();
         }

         else { $CGI::Q = new CGI($form_parameters); }
       }

       my $param = param("hello");
       print "I saw: $param\n";

 #      my $f = param("thefile");
 #      print "thefile filename: $f\n";
 #      { undef $/; print "thefile size: ", length(<$f>), "\n" }

     }
     $c->close;
     undef($c);
 }
