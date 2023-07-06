#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my $date = shift;
my $in;
if (! open $in, '<', "beelog/$date") {
    print "No log for $date.";
    exit;
}
my %users;
LINE:
while (my $line = <$in>) {
    if (index($line, ' = ') < 0) {
        next LINE;
    }
    chomp $line;
    my ($user, $cmd) = $line =~ m{\A (\S+) \s = \s (.*) \z}xms;
    if (! exists $users{$user}) {
        $users{$user} = 1;
    }
    elsif ($cmd =~ /rank\d $date/) {
        $users{$user} = $cmd;
    }
}
print scalar(keys %users) . " users<p>";
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
my %rank_name = (
    7 => 'Amazing',
    8 => 'Genius',
    9 => 'Queen Bee',
);
for my $user (grep { $users{$_} =~ /rank/ } keys %users) {
    my ($rank) = $users{$user} =~ m{rank(\d+)}xms;
    print "$uuid_screen_name{$user} $rank_name{$rank}<br>\n";
}
