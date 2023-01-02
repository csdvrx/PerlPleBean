#!/usr/bin/perl
use strict;
use warnings;

# Very rought and minimal Http::Daemon forking a few child
# you can ask them to die one-by-one by visiting /切腹
# (good for testing unicode and checking for mojibake)

#use CGI qw/ :standard /;
use Data::Dumper;
use HTTP::Daemon;
use HTTP::Date qw(time2str);
use POSIX qw/ WNOHANG /;

my $ctrlr="\r";
my $server="PPB";
my $debug=3;

my %configurable = (
 'listen-host' => '127.0.0.1',
 'listen-port' => 8081,
 'listen-clients' => 3,
 'listen-max-req-per-child' => 100,
);

my %handlers = (
 'GET' => {
  '/hello' => {'name' => "get_hello", 'code'=>\&get_hello},
  '/helloworld' => {'name' => "get_helloworld", 'code'=>\&get_helloworld},
  '/切腹' => {'name' => "get_seppuku", 'code'=>\&get_seppuku},
  '/%E5%88%87%E8%85%B9' => {'name' => "get_seppuku", 'code'=>\&get_seppuku},
 }
);

my $daemon = HTTP::Daemon->new(
 LocalAddr => $configurable{'listen-host'},
 LocalPort => $configurable{'listen-port'},
 Reuse => 1,
) or die "Can't start http listener at $configurable{'listen-host'}:$configurable{'listen-port'}";

print "Started HTTP listener at " . $daemon->url . "\n";

# Hash containing the children pid
my %chld;
# Prepare the child
if ($configurable{'listen-clients'}) {
 
 $SIG{CHLD} = sub {
  # checkout finished children
  # Don't assume we are protected from zombies by $SIG{CHLD}='IGNORE';
  #waitpid($pid,0);
  while ((my $kidpid = waitpid(-1, WNOHANG)) > 0) {
   print STDOUT "Parent:$$: child $kidpid finished\n";
   # Remove from the hash
   delete $chld{$kidpid};
  }
 };
}

# Main loop preforks all listen-clients at once if >1, otherwise just listens as=is
# We could respawn them as needed
#while (1) {
 if ($configurable{'listen-clients'} && $configurable{'listen-clients'}>1) {
  for (scalar(keys %chld) .. $configurable{'listen-clients'} - 1 ) {
   my $pid = fork;
   if (!defined $pid) { # error
    die "Can't fork for http child $_: $!";
   }
   if ($pid) { # parent
    print "Parent $$ spawned child $pid\n";
   $chld{$pid} = 1;
   } else { # child
    $_ = 'DEFAULT' for @SIG{qw/ INT TERM CHLD /};
    http_child($daemon);
    exit;
   } # pid
  } # for scalar
  sleep 1;
 } else {
  http_child($daemon);
 } # if configurable listen-clients
#}

# The actual child handling the query
sub http_child {
 my $daemon = shift;
 my $listening_req_nbr;

 while (++$listening_req_nbr < $configurable{'listen-max-req-per-child'}) {
  my ($client, $peer_addr)= $daemon->accept or last;
  # ($c, $peer_addr) = $daemon->accept : returns an HTTP::Daemon::ClientConn reference
  my $request = $client->get_request(1) or last;
  # c->get_request( $headers_only )
  # This method reads data from the client and turns it into an HTTP::Request object which is returned
  # If you pass a TRUE value as the $headers_only argument, then get_request() will return immediately after parsing the request headers and you are responsible for reading the rest of the request content.
  $client->autoflush(1); # STDOUT doesn't autoflush
  print "Request" . sprintf("[%s] %s %s\n", $client->peerhost, $request->method, $request->uri->as_string);
  if ($debug >3) {
   print "Peer addr: " . Dumper($peer_addr);
   print "Containing:\n" . $request->as_string . "EOR\n";
   my %FORM = $request->uri->query_form();
   print "Query form: " . Dumper(%FORM);
  } # if defined handler
  # Check the handlers we have
  if (defined ($handlers{$request->method}{$request->uri->as_string}{name})) {
   if (ref ($handlers{$request->method}{$request->uri->as_string}{code}) eq "CODE") {
    print "Handling ",$request->uri->as_string, " with sub ", $handlers{$request->method}{$request->uri->as_string}{name}, " \(\)\n";
    &{$handlers{$request->method}{$request->uri->as_string}{code}}($client);
   } # if code
  } else { # handlers
   print "Doing 404\n";
   do_404($client, $request->uri->as_string, "undefined");
  } # handlers
  print "Now closing " . $client->reason . "\n";
  $client->close();
  undef $client;
 } # while
} # http_child

# Simply prints plain text to the client filehandle
sub get_hello {
 my $client_fh=shift;
 my $time_str =time2str(time);
 print $client_fh "HTTP/1.1 200 OK$ctrlr
Date:  $time_str$ctrlr
Pragma: no-cache$ctrlr
Cache-control: no-cache$ctrlr
Server: $server$ctrlr
Content-Type: text/plain$ctrlr
Accept-Ranges: none$ctrlr
$ctrlr
Hello";
} # get_hello

# Print html after locally redirecting STDOUT to the client filehandle
sub get_helloworld {
  my $client_fh=shift;
  my $time_str =time2str(time);
  # the html data payload
  # to get parameters, set them like http://localhost:8765/helloworld?name=me&you=too
  # my $who = $ENV($name);
  # but first cook a header
  local *STDOUT = $client_fh;
  #print << "EOF";
  # Use a fancy indented here-doc modifier ~
  print <<~"EOF";
   HTTP/1.1 200 OK$ctrlr
   Date:  $time_str$ctrlr
   Pragma: no-cache$ctrlr
   Cache-control: no-cache$ctrlr
   Server: $server$ctrlr
   Content-Type: text/html$ctrlr
   Accept-Ranges: none$ctrlr
   $ctrlr
   <!DOCTYPE html>
   <html>
   <head><title>Hello world</title></head>
   <body>
   <h1>HELLO WORLD</h1>
   </body>
   </html>
   EOF
} # get_helloworld

sub do_404 {
  my ($fh, $path, $why)=@_;
  my $time_str = time2str(time);
  print $fh "HTTP/1.0 404 Not found$ctrlr
Date: $time_str$ctrlr
Pragma: no-cache$ctrlr
Cache-control: no-cache$ctrlr
Server: $server$ctrlr
Content-Type: text/html$ctrlr
$ctrlr
<!DOCTYPE html>
<header><title>404 $path</title></header>
<html><h1>Not found: $path $why</h1></body></html>
";
} # sub do_404

sub get_seppuku {
 my $client_fh=shift;
 local *STDOUT = $client_fh;
 my $time_str =time2str(time);
 my $lastwords="AAAAAAAAA! Server error!! $$ 切腹!!!";
 print <<~"EOF";
  HTTP/1.0 400 Server error$ctrlr
  Date: $time_str$ctrlr
  Pragma: no-cache$ctrlr
  Cache-control: no-cache$ctrlr
  Server: $server$ctrlr
  Content-Type: text/html$ctrlr
  $ctrlr
  <!DOCTYPE html>
  <header><title>$lastwords</title></header>
  <html><h1>$lastwords<h1></body></html>
  EOF
  close (STDOUT) and die ("切腹");
}

