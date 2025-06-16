#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
use Date::Simple qw/
    today
/;
use BeeHTML qw/
    Tr
    td
    th
    table
/;
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
my %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';

my $now    = today();
my $today  = $now->as_d8();
my $week   = ($now-6)->as_d8();
my $fourw  = ($now-27)->as_d8();
my %uuids;
my $nlines = 0;
open my $in, '<', "beelog/$today"
    or die "cannot open beelog for today\n";
while (my $line = <$in>) {
    ++$nlines;
    if ($line =~ m{\A (.*) [ ]=[ ]}xms) {
        $uuids{$1} = 1;
    }
}
close $in;
sub game_info {
    my ($uuid11) = @_;
    my $full = $full_uuid{$uuid11};
    my %cur_puzzles = %{ eval $cur_puzzles_store{$full} };
    my $nwords = exists $cur_puzzles{$today}?
                     (split ' ', $cur_puzzles{$today}) - 9
                   : 0;
    my $np = grep { /\A\d/ } keys %cur_puzzles;
        # do not include CP puzzles
    my ($nw, $nm) = (0, 0);
    for my $p (grep { /\A\d/ } keys %cur_puzzles) {
        if ($p >= $week) {
            ++$nw;
        }
        if ($p >= $fourw) {
            ++$nm;
        }
    }
    return words => $nwords,
           games => $np,
           week  => $nw,
           fourw => $nm;
}
my @rows = map {
               Tr(
                   td($_->{name}),
                   td($_->{words}),
                   td($_->{week}),
                   td($_->{fourw}),
                   td($_->{games}),
               )
           }
           sort {
               $b->{words} <=> $a->{words}
               ||
               $a->{name}  cmp $b->{name}
           }
           grep {
               $_->{words}      # if no words found don't count them
           }
           map {
               {
                   name => $uuid_screen_name{$_} || '?',
                   game_info($_)
               }
           }
           keys %uuids;
unshift @rows, Tr(
                   th('Name'),
                   th('Words'),
                   th('Week'),
                   th('4 Weeks'),
                   th('Total'),
               );
my $npeople = @rows;
my $pw = $npeople == 1? 'person': 'people';
my $pl = $nlines == 1? '': 's';
print "$npeople $pw, $nlines line$pl<p>\n";
print table({ cellpadding => 5}, @rows);
