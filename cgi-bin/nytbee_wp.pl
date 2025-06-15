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
my $month  = ($now-30)->as_d8();
my %uuids;
open my $in, '<', "beelog/$today"
    or die "cannot open beelog for today\n";
while (my $line = <$in>) {
    if ($line =~ m{\A (.*) [ ]=[ ]}xms) {
        $uuids{$1} = 1;
    }
}
close $in;
sub game_info {
    my ($uuid11) = @_;
    my $full = $full_uuid{$uuid11};
    my %cur_puzzles = %{ eval $cur_puzzles_store{$full} };
    my $np = grep { /\A\d/ } keys %cur_puzzles;
        # do not include CP puzzles
    my ($nw, $nm) = (0, 0);
    for my $p (grep { /\A\d/ } keys %cur_puzzles) {
        if ($p >= $week) {
            ++$nw;
        }
        if ($p >= $month) {
            ++$nm;
        }
    }
    return $np, $nw, $nm;
}
my @rows = map {
               Tr(
                   td($_->[0]),
                   td($_->[1]),
                   td($_->[2]),
                   td($_->[3])
               )
           }
           sort {
               $b->[1] <=> $a->[1]
           }
           map {
               [ $uuid_screen_name{$_} || '?', game_info($_) ]
           }
           keys %uuids;
print table({ cellpadding => 5}, @rows);
