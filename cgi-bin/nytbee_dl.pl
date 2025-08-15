#!/usr/bin/perl
# messy as I copy/pasted
# it works. :)
use warnings;
use strict;
use Date::Simple qw/
    today
/;
my $today_d8 = today()->as_d8();
use BeeUtil qw/
    slash_date
    word_score
/;
my ($uuid, $screen_name) = @ARGV;
use DB_File;
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
my %puzzle_store;
tie %puzzle_store, 'DB_File', 'puzzle_store.dbm';

my %cur_puzzles = %{ eval $cur_puzzles_store{$uuid} };

my $ext_sig = '!*+-';   # extra word sigils
                        # ! stash * bonus + lexicon - donut
my $npuzzles = 0;
my $total_words = 0;

my ($letters, $center, $npangrams, $max_score, %is_pangram, @ok_words);

my $rank_name;
my @found;
my @ranks;

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

my $list = "$screen_name-$today_d8-list.csv";
my $full = "$screen_name-$today_d8-full.csv";
my $down = "downloads";
open my $out1, '>', "../$down/$list";
print {$out1} "date,rank,all pangrams\n";
open my $out2, '>', "../$down/$full";
print {$out2} "date,letters,center,rank,all pangrams,num_hints,puzzle,donut,lexicon,bonus,stash\n";
for my $dt (sort keys %cur_puzzles) {
    ++$npuzzles;
    # get the letters, center, and the allowed list and see if all
    # of the pangrams have been found
    if (my ($cp_num) = $dt =~ m{\ACP(\d+)}xms) {
        # community puzzle
        my $cp_href = do "community_plus/$cp_num.txt";
        $letters = $cp_href->{seven};
        $center = $cp_href->{center};
        $npangrams= $cp_href->{npangrams};
        $max_score = $cp_href->{max_score};
        my @pw = @{$cp_href->{pangrams}};
        %is_pangram = map { $_ => 1 } @pw;
        @ok_words = @{$cp_href->{words}};
    }
    else {
        my ($s, $t) = split m{[|]}xms, $puzzle_store{$dt};
        my ($nwords, $nperfect, $bingo, $gn4l, $gn4l_np);
        my @pangrams;
        ($letters, $center, $nwords, $max_score,
         $npangrams, $nperfect,
         $bingo, $gn4l, $gn4l_np,
         @pangrams
        ) = split ' ', $s;
        %is_pangram = map { $_ => 1 } @pangrams;
        @ok_words = split ' ', $t;
    }
    # the number of hints *overall* is the second number
    my ($nhints) = $cur_puzzles{$dt} =~ m{\A \s* \d+ \s+ (\d+)}xms;
    # now get the words that were entered
    my @words = grep { !/\A-?[0-9]/xms } split ' ', $cur_puzzles{$dt};
    $total_words += @words;
    @found = grep { !/[$ext_sig]\z/xms } @words;

    # given $max_score determine the ranks
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
    # $npangrams = number of pangrams in the puzzle
    # $npf = number of pangrams in the found list
    compute_score_and_rank();
    my $p = $npangrams == $npf? 'p': 'n';
    print {$out1} "$dt,$rank_name,$p\n";
    print {$out2} "$dt,$letters,$center,$rank_name,$p,$nhints,";
    my (@puzzle, @donut, @bonus, @lexicon, @stash);
    for my $w (sort @words) {
        if ($w !~ s{([$ext_sig])\z}{}xms) {
            push @puzzle, $w;
        }
        else {
            my $c = $1;
            # ! stash * bonus + lexicon - donut
            if ($c eq '!') {
                push @stash, $w;
            }
            elsif ($c eq '*') {
                push @bonus, $w;
            }
            elsif ($c eq '+') {
                push @lexicon, $w;
            }
            elsif ($c eq '-') {
                push @donut, $w;
            }
        }
    }
    print {$out2} "@puzzle,";
    print {$out2} "@donut,";
    print {$out2} "@lexicon,";
    print {$out2} "@bonus,";
    print {$out2} "@stash\n";
}
close $out1;
close $out2;
print <<"EOH";
$npuzzles puzzles, $total_words total words
<p>
Links to download your puzzle files:
<p>
<a style='margin-left: 1in'
   class=alink
   href='https://ultrabee.org/$down/$list' download>List</a>
<a style='margin-left: .5in'
   class=alink
   href='https://ultrabee.org/$down/$full' download>Full</a>
EOH
