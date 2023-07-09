#!/usr/bin/env perl
use strict;
use warnings;
use BeeUtil qw/
    JON
/;
use DB_File;
my $date = shift;
my $my_screen_name = shift;
my $in;
if (! open $in, '<', "beelog/$date") {
    print "No log for $date.";
    exit;
}
my %rank_for;
my %hints_for;
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
my %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';
LINE:
while (my $line = <$in>) {
    if (index($line, ' = ') < 0) {
        next LINE;
    }
    chomp $line;
    if (my ($uuid11, $rank)
            = $line =~ m{\A (\S+) \s+ = \s+ rank(\d) \s+ $date}xms
    ) {
        my $name = $uuid_screen_name{$uuid11} || '??';
        $rank_for{$name} = $rank;
        if (! exists $hints_for{$name}) {
            my $uuid = $full_uuid{$uuid11};
            my %cur_puzzles = %{ eval $cur_puzzles_store{$uuid} };
            $hints_for{$name} = (split ' ', $cur_puzzles{$date})[0];
        }
    }
}
print scalar(keys %rank_for) . " people</p>";
print "<table>\n";
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
my $prev_rank = 0;
# display first Queen Bee down to Genius... people
#   reverse sorted by # hints
for my $name (sort {
               $rank_for{$b} <=> $rank_for{$a}
               ||
               $hints_for{$a} <=> $hints_for{$b}
               ||
               $a cmp $b
           }
           keys %rank_for
) {
    if ($rank_for{$name} != $prev_rank) {
        print "<tr><th class='lt green'>$rank_name{$rank_for{$name}}</th></tr>\n";
        $prev_rank = $rank_for{$name};
    }
    my $red_star = $name eq $my_screen_name? ' <td class="rt red">*</td>': '';
    print "<tr><td class=rt>$name</td><td align=right>&nbsp;&nbsp;$hints_for{$name}</td>$red_star</tr>\n";
}
print "</table>\n";
