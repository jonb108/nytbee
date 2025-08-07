#!/usr/bin/env perl
use strict;
use warnings;
use BeeUtil qw/
    puzzle_info
/;
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
    my @words = split ' ', $words;
    my @attrs = puzzle_info(\@words, \@pangrams);
    my $s = "$seven $center @attrs @pangrams | @words";
    print {$out} "$date $s\n";
    $puzzle_store{$date} = $s;
}
close $in;
close $out;
