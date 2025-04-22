#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;
my %cur_puzzles;
tie %cur_puzzles, 'DB_File', 'cur_puzzles_store.dbm';
unlink 'cur_puzzles_store_new.dbm';
my %cur_puzzles_new;
tie %cur_puzzles_new, 'DB_File', 'cur_puzzles_store_new.dbm';
UUID:
while (my ($uuid, $puzzles) = each %cur_puzzles) {
    my %puzzles = %{ eval $puzzles };
    my %puzzles_new;
    for my $k (sort keys %puzzles) {
        if ($uuid eq 'sahadev108!') {
            $puzzles_new{$k} = $puzzles{$k};
        }
        else {
            my @arr = split ' ', $puzzles{$k};
            my @new_arr = splice @arr, 0, 5;
            push @new_arr, 0;
            push @new_arr, @arr;
            my $s = join ' ', @new_arr;
            $puzzles_new{$k} = $s;
        }
    }
    $cur_puzzles_new{$uuid} = Dumper(\%puzzles_new);
}
