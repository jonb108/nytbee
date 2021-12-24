#!/usr/bin/perl
use strict;
use warnings;

# a poor man's database
use DB_File;
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';

# a poor man's CGI:
print "Content-Type: text/html; charset=ISO-8859-1\n\n";
my $regexp = $ENV{PATH_INFO};
$regexp =~ s{\A /}{}xms;
if ($regexp !~ s{\A -}{}xms) {
    $regexp = "\\b$regexp\\b";
}

my ($min, $hour, $day, $month) = (localtime)[ 1..4 ];
++$month;
open my $out, '>>', 'nytbee_log.txt';
printf {$out} "%02d/%02d %02d:%02d $ENV{REMOTE_ADDR} search $regexp\n",
              $month, $day, $hour, $min;
close $out;

while (my ($dt, $puz) = each %puzzle) {
    if ($puz =~ m{$regexp}xms) {
        print "$dt\n";
    }
}
