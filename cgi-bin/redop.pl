#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my %puzzle_store;
tie %puzzle_store, 'DB_File', 'puzzle_store.dbm';

open my $in, '<', 'nyt_puzzles.txt'
    or die "no nyt_puzzles.txt: $!\n";
open my $out, '>', 'nyt_puzzles_plus.txt'
    or die "no nyt_puzzles_plus.txt: $!\n";
while (my $line = <$in>) {
    chomp $line;
    my ($date, $t, $words) = $line =~ m{\A (\d+) \s+=>\s+ (.*) [|] (.*) \z}xms;
    my ($seven, $center, @pangrams) = split ' ', $t;
    my $npangrams = @pangrams;
    my %is_pangram = map { $_ => 1 } @pangrams;
    my $nperfect = 0;
    for my $p (@pangrams) {
        if (length $p == 7) {
            ++$nperfect;
        }
    }
    my @words = split ' ', $words;
    my $max_score = 0;
    my $gn4l_score = 0;
    my $gn4l_np_score = 0;
    my $nwords = @words;
    my %first_letter;
    for my $w (@words) {
        ++$first_letter{substr($w, 0, 1)};
        my $lw = length $w;
        if ($lw == 4) {
            $max_score += 1;
        }
        else {
            if ($is_pangram{$w}) {
                my $word_score = $lw + 7;
                $max_score += $word_score;
                $gn4l_score += $word_score;
            }
            else {
                $max_score += $lw;
                $gn4l_score += $lw;
                $gn4l_np_score += $lw;
            }
        }
    }
    my $bingo = keys %first_letter == 7? 1: 0;
    my $genius = int(70*$max_score/100);
    my $gn4l    = $gn4l_score    >= $genius? 1: 0;
    my $gn4l_np = $gn4l_np_score >= $genius? 1: 0;
    #print "dt $date $seven $center npan $npangrams nperfect $nperfect nwords $nwords max $max_score bingo $bingo gn4l $gn4l gn4l_np $gn4l_np @pangrams | @words\n";
    print {$out} "$date $seven $center $npangrams $nperfect $nwords $max_score $bingo $gn4l $gn4l_np @pangrams | @words\n";
    $puzzle_store{$date} = "$seven $center $npangrams $nperfect $nwords $max_score $bingo $gn4l $gn4l_np @pangrams | @words";
}
close $in;
close $out;
