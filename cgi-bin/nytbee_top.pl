#!/usr/bin/env perl
# look for C\s+YA? $date
# if so mark those screen names with a &dagger;
# to indicate possible 'trying to game the system' aka cheating.
# the C Y command IS okay for doing Bingo first ...
# i.e. when the rank is <= 4
# maybe later also look for
#     more than 5 minus word commands once level is Great
# log C\s+YA? with the $date
#
# TOP does not apply to Community Puzzles?
#
# report on Bingo levels?
# 1 for first 7
# 2 for alpha order
# 4 for minimum
# 8 for maximum - OR'ed together
# max replaces min so 11 instead of 7
# Show this at the end - if the puzzle is a bingo
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
my %genius_for;
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
        if ($line =~ m{(gn4l|gotn)\z}xmsi) {
            $genius_for{$name} = $1;
        }
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
# display Queen Bee down to Genius... people
#   reverse sorted by # hints
#   and reverse sorted by genius attainment
for my $name (sort {
                  $rank_for{$b} <=> $rank_for{$a}
                  ||
                  $hints_for{$a} <=> $hints_for{$b}
                  ||
                  $genius_for{$b} cmp $genius_for{$a}
                      # luckily 'gotn' gt 'gn4l' gt ''
                  ||
                  $a cmp $b
              }
              keys %rank_for
) {
    if ($rank_for{$name} != $prev_rank) {
        print "<tr><th class='lt green'>$rank_name{$rank_for{$name}}</th></tr>\n";
        $prev_rank = $rank_for{$name};
    }
    my $red_star = $name eq $my_screen_name? ' <span class="rt red">*</span>': '';
    my $gn = $genius_for{$name};
    if ($gn) {
        $gn .=' ';
    }
    my $sp = '&nbsp;' x 2;
    my $col3 = ($gn || $red_star)? "<td class=lt>$sp$gn$red_star</td>": '';
    print "<tr><td class=rt>$name</td>"
        . "<td align=right>$sp$hints_for{$name}</td>"
        . "$col3</tr>\n";
}
print "</table>\n";
