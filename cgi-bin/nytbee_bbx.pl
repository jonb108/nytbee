#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my ($date, $let, $sn) = @ARGV;
my $uuid11;
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
open my $in, '<', "beelog/$date";
my %sn_for;
LINE:
while (my $line = <$in>) {
    chomp $line;
    if (my ($uid) = $line =~ m{\A (\S+) \s+ =}xms) {
        if (! exists $sn_for{$uid}) {
            $sn_for{$uid} = $uuid_screen_name{$uid};
        }
    }
}
close $in;
for my $uid (keys %sn_for) {
    if ($sn_for{$uid} =~ m{\A $sn \z}xmsi) {
        $uuid11 = $uid;
        print "Bonus words with <span class=red>\u$let</span> found by $sn_for{$uid}:<p>\n";
        last;
    }
}
if (! $uuid11) {
    print "\U$sn\E: Unknown screen name<br>\n";
    exit;
}
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
my %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';
my $full_uuid = $full_uuid{$uuid11};
my $cps = $cur_puzzles_store{$full_uuid};
untie %cur_puzzles_store;
my %cur_puzzles;
if ($cps) {
    %cur_puzzles = %{ eval $cps };
}
if ($cur_puzzles{$date}) {
    my @words = sort 
                map { s{[*]\z}{}xms; ucfirst $_; }
                grep { /$let.*[*]\z/i }
                split ' ', $cur_puzzles{$date};
    print "<div class=found_words>@words</div>";
}
