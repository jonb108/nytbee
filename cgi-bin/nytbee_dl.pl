#!/usr/bin/perl
use warnings;
use strict;
use BeeUtil qw/
    slash_date
    word_score
/;
my ($uuid, $screen_name) = @ARGV;
use DB_File;
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
my %nyt_puzzles;
tie %nyt_puzzles, 'DB_File', 'nyt_puzzles.dbm';

print "The many games of $screen_name:<p>\n";
my %cur_puzzles = %{ eval $cur_puzzles_store{$uuid} };

my $ext_sig = '!*+-';   # extra word sigils
                        # ! stash * bonus + lexicon - donut
my $rank_name;
my @found;
my %is_pangram;
my @ranks;
my $max_score;
sub compute_score_and_rank {
    my $score = 0;
    WORD:
    for my $w (@found) {
        next WORD if $w =~ m{[$ext_sig] \z}xms;   # extra
        $score += word_score($w, $is_pangram{$w});
    }
    my $rank;
    RANK:
    for my $r (0 .. $#ranks-1) {
        # note that $#ranks is Queen Bee == 9
        if (   $score >= $ranks[$r]->{value}
            && $score <  $ranks[$r+1]->{value}
        ) {
            $rank_name = $ranks[$r]->{name};
            $rank = $r;
            last RANK;
        }
    }
    # special case:
    if ($score >= $max_score) {
        $rank = 9;
        $rank_name = 'Queen Bee';
    }
}
for my $dt (sort keys %cur_puzzles) {
    print slash_date($dt);
    # get the allowed list and see if all
    # of the pangrams have been found
    # split on pipe, shift two
    my ($s, $t) = split m{[|]}xms, $nyt_puzzles{$dt};
    my @ok_words = split ' ', $t;
    my @w = split ' ', $s;
    shift @w; shift @w;
    my $np = @w;
    %is_pangram = map { $_ => 1 } @w;
    @found = grep { !/\A([0-9]|$ext_sig\z)/ } split ' ', $cur_puzzles{$dt};
    $max_score = 0;
    for my $w (@ok_words) {
        $max_score += word_score($w, $is_pangram{$w});
    }
    @ranks = (
        { name => 'Beginner',   pct =>   0, value => 0 },
        { name => 'Good Start', pct =>   2, value => int(.02*$max_score + 0.5) },
        { name => 'Moving Up',  pct =>   5, value => int(.05*$max_score + 0.5) },
        { name => 'Good',       pct =>   9, value => int(.08*$max_score + 0.5) },
        { name => 'Solid',      pct =>  15, value => int(.15*$max_score + 0.5) },
        { name => 'Nice',       pct =>  25, value => int(.25*$max_score + 0.5) },
        { name => 'Great',      pct =>  40, value => int(.40*$max_score + 0.5) },
        { name => 'Amazing',    pct =>  50, value => int(.50*$max_score + 0.5) },
        { name => 'Genius',     pct =>  70, value => int(.70*$max_score + 0.5) },
        { name => 'Queen Bee',  pct => 100, value => $max_score },
    );
    my $npf = grep { $is_pangram{$_} } @found;
    compute_score_and_rank();
    my $p = $np == $npf? 'p': '';
    print " $rank_name $p<br>\n";
}
