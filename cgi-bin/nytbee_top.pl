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
print scalar(keys %users) . " people<p>";
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
my %rank_name = (
    0 => 'Beginner',
    1 => 'Good Start',
    2 => 'Moving Up',
    3 => 'Good',
    4 => 'Solid',
    5 => 'Nice',
    6 => 'Great',
    7 => 'Amazing',
    8 => 'Genius',
    9 => 'Queen Bee',
);
# display first Queen Bee down to Genius... people
#   reverse sorted by # hints
for my $user (grep { $users{$_} =~ /rank/ } keys %users) {
    my ($rank) = $users{$user} =~ m{rank(\d+)}xms;
    # give them a screen name if they don't have one...
    my $name = $uuid_screen_name{$user} || '??';
    print "$name $rank_name{$rank}<br>\n";
}
