#!/usr/bin/perl
use strict;
use warnings;

use open qw(:std);              # should use unicode, but (:std :utf8) gives mojibake

# Send the piped content as a http POST multipart

## Minimalistic set of dependancies: must not come from CPAN for portability
use Data::Dumper;                   # for cheap debug, always present by default
use HTTP::Request::Common;          # for creating the request
use LWP::UserAgent;                 # for sending the request
use MIME::Base64 qw(encode_base64); # for the eventual output encoding
use Encode qw(decode);              # for more precise input encoding
require Encode::Detect;             # for more precise input encoding

# Global variables to hardcode behaviors
my $debug=0;

# FIXME: should have a non-deterministic end after WebKitFormBoundary
my $boundary = "WebKitFormBoundaryVy2camt7RAUeatMy";

# Besides the content, we need a filename and a URL
my $argv0_filename;
my $argv1_httppost;

# Default to binary mode
my $forcetextmode=0;

# In debug mode, these will use hardcoded values
if ($debug>0) {
 $argv1_httppost="http://localhost:8765/mem/add.cgi";
 $argv0_filename="input.tsv";
 $forcetextmode=1;
} else {
 # use the parameters
 unless (scalar(@ARGV)>=2) {
  die("$0 will post textual content (with 2 arguments) or base64-encoded binary content (if a 3rd arg is present)\n\nUsage:\n\tcat content-to-be-sent | perl $0 filename-to-be.used http:://url/to/post.it\n\tcat binary-content | perl $0 filename-to-be.used http:://url/to/post.it textmode\n");
 } # unless
 # A 3rd argument will engage textmode
 if (scalar(@ARGV)==2) {
  $forcetextmode=1;
 }
 # TODO: a 4th argument could be a bearer token, randomly determined at runtime by perlplebin
 # Then could be using a 2nd header besides Content-Type, like:
 # $headers = {'Content-Type' => 'multipart/form-data', 'Authorization' => 'Bearer '.$token.''};
} # if

# In normal mode, the commandline parameters will be preferred
$argv0_filename = $ARGV[0];
$argv1_httppost = $ARGV[1];

# STDIN will be read by the diamond operator or in binmode with buffered 1k reads
my $stdin_content;

# Which poses the problem of the encoding of stdin:
#  in forced textmode, Encode::Detect will transcode to UTF-8
my $stdin_content_utf8;
#  in binary mode, no charset will be given: $stdin_content will be used as-is after base64 encoding
my $stdin_content_b64;

# So we do very differently depending on the mode used
if ($forcetextmode >0) {
 # Read from STDIN line by line into an array
 while(my $stdin_line = <STDIN>) {
  #push (@stdin_array, $stdin_line);
  $stdin_content .= $stdin_line;
 } # foreach
 # then encode this content in base64
 $stdin_content_b64=encode_base64($stdin_content);
} else { # if forcetextmode
 my $stdin_fh = \*STDIN;
 # simple buffered read for each kb of binary data
 binmode $stdin_fh;
 while (read ($stdin_fh, my $onek, 1024)) {
  $stdin_content .= $onek;
 }
 close ($stdin_fh);
 # then convert this content to UTF-8
 my $stdin_content_utf8= decode("Detect", $stdin_content);
} # if forcetextmode

# Simplest approach: not applicable, as we want to send something that isn't a file, and we may not be able to create a temporary file
# like https://stackoverflow.com/questions/12819260/perl-upload-file-using-httprequest
#my $request = POST "$argv1_httppost",
#  Content_Type => 'multipart/form-data',
#  Content => [
#    uploadfile => [ "./example.tsv" ],
#  ];

## Approach 1: Handcraft the body with the textual data

## WARNING: suffixing $stdin_content by by \r will results in that being present in the transferred file!!
my $content_text ="----$boundary\r
Content-Disposition: form-data; name=\"uploadfile\"; filename=\"$argv0_filename\"\r
Content-Type: text/plain; charset=UTF-8\r
\r
$stdin_content
----$boundary--\r\n";

# But we may be sending binary data, or encounter weird transcoding (mojibake) issues

## Approach 2 (preferred): Handcraft the body with base64 encoded data to avoid any issue with the content

# Do as above except with an extra carriage return after the base64 payload
# TODO: no charset is passed, and it's not clear if Content-Type: application/octet-stream\r could help
my $content_b64 ="----$boundary\r
Content-Disposition: form-data; name=\"uploadfile\"; filename=\"$argv0_filename\"\r
Content-Type: text/plain;\r
Content-Transfer-Encoding: Base64\r
\r
$stdin_content_b64\r
----$boundary--\r\n";

# Then prepare a request depending on the mode used;
my $request;

#'multipart/form-data' must be specified, otherwise defaults to 'application/x-www-form-urlencoded'
if ($forcetextmode) {
 $request = POST (
  $argv1_httppost,
  Content_Type => "multipart/form-data; boundary=--$boundary",
  Content => $content_b64
 );
} else { # if forceusebase64
 $request = POST (
  $argv1_httppost,
  Content_Type => "multipart/form-data; boundary=$boundary",
  Content => $content_text
 );
} # if forceusebase64

# Post the request while showing what's happening:
print STDERR "Request:\n";
print STDERR Dumper $request;
my $ua = LWP::UserAgent->new;
my $result=$ua->request($request ) ;
print STDERR "Result:\n";
print STDERR Dumper $result;
