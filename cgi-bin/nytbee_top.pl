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
my $qb_nwords = shift;
my $my_screen_name = shift;
my $sp = '&nbsp;' x 2;
my $in;
if (! open $in, '<', "beelog/$date") {
    print "No log for $date.";
    exit;
}
# Bingo is complicated! :) :(
my (%min_bingo_score_for, %min_bingo_hints_for); # < 8
my (%max_bingo_score_for, %max_bingo_hints_for); # >= 8
my (%bingo_score_for, %bingo_hints_for);

my %genius_for;
my %rank_for;
my %hints_for;
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
my %screen_name_uuid;
tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';
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
    if (my ($r_uuid11, $rank)
            = $line =~ m{\A (\S+) \s+ = \s+
                         rank(\d) \s+ $date
                        }xms
    ) {
        my $screen_name = $uuid_screen_name{$r_uuid11};
        if ($rank >= 8 && ! $screen_name) {
            # assign them a screen name
            # no need to inform them what it is.
            my $i = 110;
            while (exists $screen_name_uuid{"Buzz$i"}) {
                ++$i;
            }
            $screen_name = "Buzz$i";
            $uuid_screen_name{$r_uuid11} = $screen_name;
            $screen_name_uuid{$screen_name} = $r_uuid11;
        }
        $rank_for{$screen_name} = $rank;
        if ($line =~ m{(gn4l|gotn)\z}xmsi) {
            $genius_for{$screen_name} = $1;
        }
        if (! exists $hints_for{$screen_name}) {
            my $uuid = $full_uuid{$r_uuid11};
            my %cur_puzzles = %{ eval $cur_puzzles_store{$uuid} };
            $hints_for{$screen_name} = (split ' ', $cur_puzzles{$date})[0];
        }
    }
    elsif (my ($b_uuid11, $bingo_score, $bingo_hints)
               = $line =~ m{\A (\S+) \s+ = \s+
                            bingo \s+ $date \s+
                            (\d+) \s+ (\d+)
                            \s* \z
                           }xms
    ) {
        my $screen_name = $uuid_screen_name{$b_uuid11};
        if (! $screen_name) {
            # assign them a screen name
            # no need to inform them what it is.
            my $i = 110;
            while (exists $screen_name_uuid{"Buzz$i"}) {
                ++$i;
            }
            $screen_name = "Buzz$i";
            $uuid_screen_name{$r_uuid11} = $screen_name;
            $screen_name_uuid{$screen_name} = $r_uuid11;
        }
        if ($bingo_score < 8) {
            # min bingo
            if (! exists $min_bingo_score_for{$screen_name}) {
                $min_bingo_score_for{$screen_name} = $bingo_score;
                $min_bingo_hints_for{$screen_name} = $bingo_hints;
            }
        }
        else {
            # max bingo
            if (! exists $max_bingo_score_for{$screen_name}) {
                $max_bingo_score_for{$screen_name} = $bingo_score;
                $max_bingo_hints_for{$screen_name} = $bingo_hints;
            }
        }
    }
}
# tally up the bingo scores
for my $screen_name (keys %min_bingo_score_for) {
    $bingo_score_for{$screen_name} = $min_bingo_score_for{$screen_name};
    $bingo_hints_for{$screen_name} = $min_bingo_hints_for{$screen_name};
}
for my $screen_name (keys %max_bingo_score_for) {
    $bingo_score_for{$screen_name} += $max_bingo_score_for{$screen_name};
    $bingo_hints_for{$screen_name} += $max_bingo_hints_for{$screen_name};
}
print scalar(keys %rank_for) . " people</p>";
if (%bingo_score_for) {
    print "<table>\n";
    print "<tr><th class='lt green'>Bingo</th></tr>\n";
    print "<tr><th class='rt'>Name</th><th class=rt>${sp}Score</th><th class=rt>${sp}Hints</th></tr>\n";
    for my $sn (sort {
                    $bingo_score_for{$b} <=> $bingo_score_for{$a}
                    ||
                    $bingo_hints_for{$a} <=> $bingo_hints_for{$b}
                    ||
                    $a cmp $b
                }
                keys %bingo_score_for
    ) {
        print "<tr><td>$sn</td><td>$sp$bingo_score_for{$sn}</td><td>$sp$bingo_hints_for{$sn}</td>";
        if ($sn eq $my_screen_name) {
            print "<td><span class='rt red'>$sp*</span></td>";
        }
        print "</tr>\n";
    }
    print "</table><p>\n";
}
#
# for the Genius people see how close
# they got to Queen Bee.
#
my %queen_minus_for;
for my $sn (keys %rank_for) {
    if ($rank_for{$sn} == 8) {
        # Genius
        my $uuid11 = $screen_name_uuid{$sn};
        my $full_uuid = $full_uuid{$uuid11};
        # check $@ and return value 
        my %cur_puzzles = %{ eval $cur_puzzles_store{$full_uuid} };
        my $nwords = grep { /^[a-z]+$/ }
                     split ' ', $cur_puzzles{$date};
        my $left = $qb_nwords - $nwords;
        $queen_minus_for{$sn} = $left;
    }
}
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
my $name_hints = 0;
my $prev_rank = 0;
# display Queen Bee down to Genius... people
#   reverse sorted by # hints
#   and reverse sorted by genius attainment
for my $screen_name (sort {
                         $rank_for{$b} <=> $rank_for{$a}
                         ||
                         $hints_for{$a} <=> $hints_for{$b}
                         ||
                         $genius_for{$b} cmp $genius_for{$a}
                             # luckily 'gotn' gt 'gn4l' gt ''
                         ||
                         $queen_minus_for{$a} <=> $queen_minus_for{$b}
                         ||
                         $a cmp $b
                     }
                     keys %rank_for
) {
    if ($rank_for{$screen_name} != $prev_rank) {
        print "<tr><th class='lt green' colspan=2>$rank_name{$rank_for{$screen_name}}</th>";
        if ($rank_for{$screen_name} == 8) {
            print "<th style='text-align: right; font-size: 13pt;'>Words<br>To QB</th>";
        }
        print "</tr>\n";
        if (! $name_hints) {
            print "<tr><th class='rt'>Name</th><th class=rt>${sp}Hints</th></tr>\n";
            $name_hints = 1;
        }
        $prev_rank = $rank_for{$screen_name};
    }
    my $red_star = $screen_name eq $my_screen_name? ' <span class="rt red">*</span>': '';
    my $gn = $genius_for{$screen_name};
    if ($gn) {
        $gn .= ' ';
    }
    my $col3 = ($gn || $red_star)? "<td class=lt>$sp$gn$red_star</td>": '';
    print "<tr><td class=rt>$screen_name</td>"
        . "<td align=right>$sp$hints_for{$screen_name}</td>"
        . ($prev_rank != 8? '': "<td align=right>$queen_minus_for{$screen_name}<td>")
        . "$col3</tr>\n";
}
print "</table>\n";
