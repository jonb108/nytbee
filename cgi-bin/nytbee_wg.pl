#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my %screen_name_uuid;
tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';
my $sn = shift;
$sn = ucfirst lc $sn;
$sn =~ s{_(.)}{uc $1}xmsge;
my $uuid11 = $screen_name_uuid{$sn};
if (! $uuid11) {
    print "No such screen name: $sn";
    exit;
}
my %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';
my $uuid = $full_uuid{$uuid11};
if (! $uuid) {
    print "no full uuid for $uuid11??\n";
    exit;
}
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
my %puzzles = %{ eval $cur_puzzles_store{$uuid} };
my $np = keys %puzzles;
print "$np<br>";
my $all = shift;
if ($all) {
    for my $p (sort keys %puzzles) {
        print "$p<br>\n";
    }
}
