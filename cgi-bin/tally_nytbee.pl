#!/usr/bin/perl
use strict;
use warnings;

use DB_File;
my %puzzle;
tie %puzzle, 'DB_File',
             '/var/www/vhosts/85/241411/webspace/cgi-bin/nyt_puzzles.dbm';

print scalar(keys %puzzle), "\n"; exit;

print "date, center, #pangrams, #words, #4words, #maxlen, score\n";
for my $dt (sort keys %puzzle) {
    my ($s, $words) = split /\s*[|]\s*/, $puzzle{$dt};
    my ($seven, $center, @pangrams) = split ' ', $s;
    my %is_pangram = map { $_ => 1 } @pangrams;
    my @words = split ' ', $words;
    my $longest = 0;
    my $score = 0;
    for my $w (@words) {
        my $l = length $w;
        if ($l > $longest) {
            $longest = $l;
        }
        $score += ($l == 4? 1: $l) + ($is_pangram{$w}? 7: 0);
    }
    my $date = substr($dt, 4, 2)
             . '/'
             . substr($dt, 6, 2)
             . '/'
             . substr($dt, 0, 4)
             ;
    printf "%s, %s, %d, %d, %d, $longest, $score\n",
        $date,
        uc $center,
        scalar(@pangrams),
        scalar(@words),
        scalar(grep { length == 4 } @words)
        ;
}
