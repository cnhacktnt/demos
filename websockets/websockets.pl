#!/usr/bin/env perl
#

use strict;
use warnings;
use FindBin qw/$Bin/;
use Mojolicious::Lite;
use Mojo::IOLoop;
use Mojo::Client;
use Parallel::Scoreboard;
use JSON;
use MIME::Base64;

$| = 1;
undef @ARGV;
push @ARGV, "daemon", "--listen", "http://localhost:2012";

my @pids;
my $board = Parallel::Scoreboard->new(
	base_dir => "$Bin/scoretmp"
);
$board->cleanup();

my $ua = Mojo::Client->new();
my %url = (
	flickr => 'http://www.flickr.com/photos/',
	yupoo => 'http://www.yupoo.com/explore/',
	instagram => 'http://instagr.am/api/v1/feed/popular/'
);

my %regex = (
	flickr => qr/<img src="([^"]+)"[^<>]+ class="pc_img"/,
	yupoo => qr/<img src="([^"]+)"[^<>]+ class="Photo"/,
	instagram => qr/"url": "(http:\/\/[^"]+?)", "width": 150,/
);


for my $site (keys %url) {

	my $pid = fork(); 

	if ($pid) {
		
		push @pids, $pid;
		
	} elsif ($pid == 0) {

		while (1) {
		
			my $html = $ua->get($url{$site})->res->body;
            next unless $html;
			my ($imgurl) = $html =~ /$regex{$site}/;
			my $status = $board->read_all();
			my ($old_imgurl) = split /\t/, $status->{$$}
				if exists $status->{$$};

			if ($old_imgurl && $old_imgurl eq $imgurl) {
				sleep 3;
				next;
			}

			printf "%-7s - %s\n", $site, $imgurl;
			my $img = $ua->get($imgurl)->res->body;
			$img = encode_base64($img);
			$board->update("$imgurl\t$img");
			sleep 3;
		
		}
	
	} else {
	
		die "Can't fork: $!\n";
	}
}

print "Server started...\n"; 
print "Pids: @pids\n";


my %client;
my $json = JSON->new;
my $loop = Mojo::IOLoop->singleton;

websocket '/' => sub {
	my $self = shift;
	warn "\n*** client connected\n\n";

	$self->finished( sub { warn "\n*** client disconnected\n" } );

	my $sender;
	$sender = sub {
		my $status = $board->read_all();
		my $msg = "";

		for my $pid (sort {$a <=> $b} keys %$status) {

			my ($url, $img) = split /\t/, $status->{$pid};
			$msg.= '<img src="data:image/jpg;base64,'.$img.'"> ';	
		}

		$self->send_message($json->encode({ type => 'message', data => $msg }));
		$loop->timer('0.5', $sender);

	};

	$sender->();

};

get '/' => 'index';

app->log->level("error");
app->start;

__DATA__

@@ index.html.ep
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
body {text-align: center;}
img {float: left; margin: 0 2px; width: 100px; height: 67px;}
#content {margin: 160px auto; width: 320px;}
</style>
</head>

<body>
<div id="content">Wait...</div>

<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js"></script>
<script src="http://jquery-json.googlecode.com/files/jquery.json-2.2.min.js"></script>
<script src="http://jquery-websocket.googlecode.com/files/jquery.websocket-0.0.1.js"></script>
<script>
var ws = $.websocket("ws://127.0.0.1:2012/", {
	events: {
		message: function(e) { $('#content').html(e.data) }
	}
});
</script>
</body>
</html>



