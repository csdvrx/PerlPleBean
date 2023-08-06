#!/usr/bin/perl
### Simple HTTP server parsing GET uri-encoded parameters

# TODO 1: same in HTTPS + should create a cert as needed
# can't publish on dns like dane
# cf https://security.stackexchange.com/questions/68504/storing-ssl-certificates-in-dns-records
# try rfc8659-like: publish over mdns a CAA record that browsers might check:
# something.local 40 IN CAA 0 issue "localhost."
# something.local 40 IN CAA 0 issuewild ";"
# something.local 40 IN CAA 0 iodef "http://localhost/caa/enforce;"
# cf https://en.wikipedia.org/wiki/DNS_Certification_Authority_Authorization
#
# TODO 2: using a nonce through 401 like rfc2617 obsoleting rfc2069
# cf https://en.wikipedia.org/wiki/Digest_access_authentication
#  - md5 hash1: username, authentication realm and password
#  - md5 hash2: method and uri
#  - md5 of (hash1, server nonce, request counter, client nonce, qop, hash2)
# HA1 = MD5( "Mufasa:testrealm@host.com:Circle Of Life" ) = 939e7578ed9e3c518a452acee763bce9
# HA2 = MD5( "GET:/dir/index.html" ) = 39aff3a2bab6126f332b942af96d3366
# Response = MD5( "939e7578ed9e3c518a452acee763bce9:\
#             dcd98b7102dd2f0e8b11d0f600bfb0c093:\
#             00000001:0a4f113b:auth:\
#             39aff3a2bab6126f332b942af96d3366" )
# = 6629fae49393a05397450978507c4ef1
#
# Can be requested with a header like
#WWW-Authenticate: Digest realm="testrealm@host.com", qop="auth", nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="whatever"
# opaque can be used to seed some information to the client,
# which will then preserve it case of redirects
   

## Modern perl
use strict;
use warnings;

## Modules used
use Data::Dumper;                   # For easily printing data structures
use HTTP::Date   qw(time2str);      # For converting epochs to http dates
use HTTP::Daemon;                   # For the HTTP server basics
use HTTP::Status;                   # For HTTP codes
use MIME::Base64;                   # For base64 decoding

# apt-get install libhttp-date-perl libhttp-daemon-perl
# could consider libhttp-daemon-ssl-perl

# HTTP:: is not part of perl core, so may have to fatpack it
# can use .pm from the local dir:
#  BEGIN { unshift @INC, '.' }
# or more simple tricks like that
# cf https://stackoverflow.com/questions/728597/how-can-my-perl-script-find-its-module-in-the-same-directory

## Global variables
my $server_name = "Tests $^O"; # will provide the operating system in the headers
my $time_str = &httpdatentime; # ref to the sub to always be up-do-date (pun intended)
my $ctrlr = "\r";              # to clearly show (or test) where carrier return is needed
my %users = ( MyName => 'SecretPassword' );
my $http_addr='127.0.0.1';
my $http_port=8001;

## Subs

# Create a nicely formatted time string from the current epoch
sub httpdatentime {
 time2str(time); # Time::HiRes has time() but we only import gettimeofday()
}

# Parse uri encoded parameters
sub get_uri_data {
 # RFC-1866 query strings: https://en.wikipedia.org/wiki/Query_string
 # - type 1: HTTP GET (within the URI)
 # - type 2: POST (data within the body)
 # either way, ends up in $input after branching
 my $input=shift;
 # NB: outside of this RFC, type 3: POST with multipart
 # TODO: around line 815 of perlplebean (0: Get the data), improve the branching
 # by checking the method and the datatype:
 #  - get_form_data should be get_multipart_data (iff POST),
 #  - get_uri_data should be get_query_data and pass the relevant part:
 #   - url (iff GET)
 #   - body (iff POST)
 # so that it can be turned into a hash here:
 my %kv;

 # To decode:
 # - plus means space
 $input =~ tr/+/ /;
 # - any %HH is to be replaced by the ASCII of the hexadecimal,
 # so convert digits like 2F to ascii: %2F becomes / (47 decimal)
 # cf https://en.wikipedia.org/wiki/Percent-encoding
 #$input =~ s/%(\w\w)/sprintf("%c", hex($1))/ge;
 $input=~ s/%([\dA-Fa-f][\dA-Fa-f])/pack ("C", hex ($1))/eg;
 # FIXME: incorrect, risk adding spurrious & that break the splitting
 # the %HH regex should apply after splitting even if it's wasteful
 # - then & separate key=value pairs
 foreach my $pair (split(/&/, $input)) {
  # - then = separates the key from the value
  my ($key, $value) = split (/=/, $pair);
  # while = separates keys from values
  $kv{$key}="$value";
 } # foreach pair
 return \%kv;
} # sub get_uri_data

# Safe defaults for environment variables
$ENV{'PATH'} = "/usr/bin";
delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

# Start a server, could handle the signal to save the current hashes
print "$server_name starting, press Ctrl+C to send a quit signal.\n";
my $daemon = HTTP::Daemon->new(
 LocalAddr => $http_addr,
 LocalPort => $http_port,
 Reuse=>1
) or die "Internal error: $!";

# Should be a default, but set it to be on the safe side:
*STDOUT->autoflush();
print "Please use either:\n";
print "a browser on: <a href=\"", $daemon->url, "\">this URL</a>\n";
print "on just curl: curl -u MyName:SecretPassword --basic http://$http_addr:$http_port/submit -v\n";

# Main loop on requests with no threads or anything complicated:
while (my $client = $daemon->accept) {
 # Not dispatching to a client, so autoflush too
 $client->autoflush();

 REQUEST:
  # Get the whole request instead of just the header
  # could be long if say uploading with POST
  # but we only accept GET
  while (my $request = $client->get_request) {
   # Still, might want to check the headers and send error 414 for a GET of >8k
   if ($request->method ne 'GET') { 
    #  && $request->method ne 'POST') {
    $client->send_error(200);
    next REQUEST;
   } # if not GET

   # Anything not passing authentication should be forbidden,
   # so let's leave a trace
   #print "Request:\n";
   #print Dumper($request);

   # by default, consider unauthorized
   my $authorized=0;
   # Can then do a basic auth like rfc7617 (obsoleting rfc2617):
   # Authorization: Basic <credentials>
   # where credentials is a base64enc of userid:password
   if (defined($request->header('Authorization'))) {
    my $auth_base64=$request->header('Authorization');
    if ($auth_base64 =~ m/^Basic /) {
     print "basic auth detected:\n";
     print Dumper($auth_base64);
     $auth_base64=~ s/^Basic //g;
     my $auth=decode_base64($auth_base64);
     print "auth: \n";
     print Dumper($auth);
     my ($user, $pass) = split (/:/, $auth);
     if (defined($users{$user})) {
      if ($users{$user} =~ m/$pass/) {
       # FIXME: not good for a security perspective, but good for tests
       print "Good password $pass\n";
       $authorized=1;
      } else {
       print "Bad password $pass\n";
       $client->send_error(403);
       next REQUEST;
      } # else
     } else { # if user
       print "Bad user: $user\n";
     } # if user
    # } elsif ($auth_base64 =~ m/Digest/) { # if not match basic
    } # if match
   } else {
    print "No auth detected\n";
   } # if defined

   # Chromium based browser seem to try without the password,
   # even if given a URL which encodes the password,
   # even if using a form action that encodes the password
   # <form action="http://Noah:ark\@$http_addr:$http_port/submit">
   # 
   if ($authorized==0) {
    # Output to the client browser with a local scope to redirect STDOUT
    # Otherwise must talk to the browser with:
    #  $client->send_header ($field, $value)
    #  $client->send_response( $res )
    local *STDOUT = $client;
    print <<~"EOF";
     HTTP/1.1 401 Unauthorized$ctrlr
     Date:  $time_str$ctrlr
     Pragma: no-cache$ctrlr
     Cache-control: no-cache$ctrlr
     Server: $server_name$ctrlr
     WWW-Authenticate: Basic$ctrlr
     Content-Type: text/html$ctrlr
     Accept-Ranges: none$ctrlr
     $ctrlr
     <html><head><title>Unauthorized</title></head>
     <h1>You must use Basic Auth</h1>
     Example for the URL: http://username:password\@$http_addr:$http_port/
     </body>
     </html>
     EOF
   } else {
    local *STDOUT = $client;
    print <<~"EOF";
     HTTP/1.1 200 OK$ctrlr
     Date:  $time_str$ctrlr
     Pragma: no-cache$ctrlr
     Cache-control: no-cache$ctrlr
     Server: $server_name$ctrlr
     Content-Type: text/html$ctrlr
     Accept-Ranges: none$ctrlr
     $ctrlr
     <html><head><title>Enter the name for the GET form</title></head>
     <form action="/submit">
     <body>
     <label for="named">What is the name?</label>
     <input name="name" id="named" value="" />
     <button type="submit" name="submit">Send</button>
     </form>
     EOF
     # FIXME: this ugly thing demonstrate how to do trickle-down to keep the connection
     # but should use Transfer-Encoding chunked
     my $j=0;
     while ($j<10) {
             $j=$j+1;
             print "test $j<br/>";
             sleep (1);
     }
     print ("</body></html>");
#     </body>
#     </html>
   } # local scope

   # For both simplicity and CGI-Compatibility, prepare a hash of the key parts:
   my %cgi;
   $cgi{'REQUEST_URI'    } = $request->uri->as_string;
   # The URL-encoded information that is sent with GET method request.
   $cgi{'QUERY_STRING'   } = $request->url->query;
   # The only methods supported here are get and post
   $cgi{'REQUEST_METHOD' } = $request->method;
   # The protocol however can range from HTTP 0.9 to 1.1
   $cgi{'SERVER_PROTOCOL'} = $request->protocol;
   # The length of the query information. It's available for POST requests
   $cgi{'CONTENT_LENGTH' } = length($request->content);
   # The data type of the content. Used when the client is sending attached content to the server. For example file upload, etc.
   $cgi{'CONTENT_TYPE'   } = $request->header('Content-Type');
   # The set cookies in the form of key & value pair.
   $cgi{'HTTP_COOKIE'    } = $request->header('Cookie');
   # The page leading to another is useful for redirects
   $cgi{'HTTP_REFERER'   } = $request->header('Referer');
   # The name of the web browser.
   $cgi{'HTTP_USER_AGENT'} = $request->header('User-Agent');
   # The auth string
   $cgi{'HTTP_AUTHORIZATION'} = $request->header('Authorization');


   # separate GET with an empty body (with parameters in the URL)
   # from POST with application/x-www-form-urlencoded containing the same thing within the body
   my %data;
   if (defined($cgi{'CONTENT_TYPE'}) && defined ($cgi{'REQUEST_METHOD'})) {
    if ($cgi{'CONTENT_TYPE'} =~ m/multipart\/form-data/
         &&
        $cgi{'REQUEST_METHOD' } =~ m/POST/) {
     die("HTTP POST without a query string is unsupported\n");
    } # if type 3
    if ($cgi{'CONTENT_TYPE'} =~ m/application\/x-www-form-urlencoded/
         &&
        $cgi{'REQUEST_METHOD' } =~ m/POST/) {
     # the data is in the body, after Content-Length: and an empty line
     %data=get_uri_data($request->content);
    } # if type 2
    if ($cgi{'CONTENT_TYPE'} =~ m/application\/x-www-form-urlencoded/
         &&
        $cgi{'REQUEST_METHOD' } =~ m/GET/) {
     %data=get_uri_data($cgi{'QUERY_STRING'});
    } # if type 1
   }

 } # while my request
 $client->close;
 undef($client);
} # while my client

exit 0;

# In case it's not used as a standalone
1;
__END__
