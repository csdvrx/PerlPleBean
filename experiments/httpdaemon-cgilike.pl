#!/usr/bin/perl -w

use 5.005;
use strict;

BEGIN { unshift @INC, '.' }

use HTTP::Daemon;
use HTTP::Status;
use IPC::Open2;

sub SERVER_NAME ()   { 'localhost' }
sub HTTP_PORT ()     { 8000        }
sub PERL_DIR ()      { '/usr/bin'  }
sub DOCUMENT_ROOT () { '.'         }

*STDOUT->autoflush();

my $daemon
    = HTTP::Daemon->new( LocalAddr => SERVER_NAME, LocalPort => HTTP_PORT )
      or die "Internal error: $!";

print "Press Ctrl+C to send a quit signal.\n";

$ENV{'PATH'} = PERL_DIR;
delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

while (my $client = $daemon->accept) {
    $client->autoflush();

    my $pid;

    REQUEST:
    while (my $request = $client->get_request) {
        if ($request->method ne 'GET' && $request->method ne 'POST') {
            $client->send_error(RC_NOT_IMPLEMENTED);
            next REQUEST;
        }
        if ($request->url->path =~ m{ [./\\]{2} }xms) {
            $client->send_error(RC_FORBIDDEN);
            next REQUEST;
        }

        my $filename = $request->url->path =~ m{ / \Z }xms
            ? DOCUMENT_ROOT . $request->url->path . 'index.html'
            : DOCUMENT_ROOT . $request->url->path
            ;
        if (-d $filename) {
            $filename .= '/index.html';
        }

        if ($filename =~ m{ [.] cgi \Z }ixms) {
            my $content = $request->content;
            my ($port, $ip_addr) = sockaddr_in(getpeername $client);

            $ENV{'CONTENT_LENGTH' } = length $content;
            $ENV{'CONTENT_TYPE'   } = $request->header('Content-Type');
            $ENV{'HTTP_COOKIE'    } = $request->header('Cookie');
            $ENV{'HTTP_REFERRER'  } = $request->header('Referer');
            $ENV{'HTTP_USER_AGENT'} = $request->header('User-Agent');
            $ENV{'QUERY_STRING'   } = $request->url->query;
            $ENV{'REMOTE_ADDR'    } = inet_ntoa($ip_addr);
            $ENV{'REMOTE_HOST'    } = gethostbyaddr $ip_addr, AF_INET;
            $ENV{'REQUEST_METHOD' } = $request->method;

            local *CGI_REQUEST;
            local *CGI_RESPONSE;

            $pid = open2(
                       \*CGI_RESPONSE,
                       \*CGI_REQUEST,
                       'perl',
                       '-T',
                       '-w',
                       $filename
                   );

            *CGI_REQUEST->autoflush();
            *CGI_RESPONSE->autoflush();

            binmode *CGI_REQUEST;
            print {*CGI_REQUEST} $content;
            *CGI_REQUEST->close;

            binmode *CGI_RESPONSE;
            my $response = do { local $/; <CGI_RESPONSE> };
            *CGI_RESPONSE->close;

            waitpid $pid, 0;
            if ($?) {
                $client->send_error(RC_INTERNAL_SERVER_ERROR);
                next REQUEST;
            }

            $client->send_basic_header;
            print {$client} $response;
            $client->force_last_request;
        }
        else {
            $client->send_file_response($filename);
            $client->force_last_request;
        }
    }

    $client->close;
    undef $client;
}

exit 0;

1;
__END__
