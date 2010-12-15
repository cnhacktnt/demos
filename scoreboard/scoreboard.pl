#!/usr/bin/env perl
# cnhackTNT

use strict;
use Parallel::Scoreboard;
use IO::File;

# set CHLD signal to IGNORE, let OS to reap the child process.
$SIG{'CHLD'} = 'IGNORE';

# scoreboard object.
my $scoreboard = Parallel::Scoreboard->new(
	base_dir => "scoreboard",
);

my @pids;

 # 3 child processes
for (1..3) {

    # fork multi processes
	my $pid = fork();

	if ($pid) { # if $pid > 0, then we are in the parent process
		
		push @pids, $pid # push current child pid to @pids 
		
	} elsif ($pid == 0) { # if $pid == 0, then we are in the child process

		while (1) {

			# update the scoreboard with a random number 1~10
			$scoreboard->update(int(rand(9)) + 1);
			sleep 1;
		
		}
	
	} else {
		# some thing wrong, fork failed.	
		die "Can't fork: $!\n";
	}
}

# set INT signal to handle "ctrl+c"
$SIG{'INT'} = sub {
	print "Daddy asked me to quit...\n";
	kill 'TERM', $_ for @pids; # kill all child processes
	sleep 3;
	$scoreboard->cleanup(); # clean scoreboard
	print "THE END.\n";
	exit;
};

print "I am the parent process, my pid is: $$\n";
print "my children are: @pids\n\n";

while (1) {
	my $status = $scoreboard->read_all(); 

	# get status, sorted by pid
	for my $pid (sort {$a <=> $b} keys %$status) {
		print "child $pid says ".$status->{$pid}."\n";
	}

	print "\n";
	sleep 3;
}
