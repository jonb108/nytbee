#!/usr/bin/perl
use strict;
use warnings;

# a poor man's database
use DB_File;
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';

my ($min, $hour, $day, $month) = (localtime)[ 1..4 ];
++$month;
open my $out, '>>', 'nytbee_log.txt';
printf {$out} "%02d/%02d %02d:%02d $ENV{REMOTE_ADDR} same\n",
              $month, $day, $hour, $min;
close $out;

# a poor man's CGI:
print "Content-Type: text/html; charset=ISO-8859-1\n\n";
my $seven = $ENV{PATH_INFO};
$seven =~ s{\A /}{}xms;

while (my ($dt, $puz) = each %puzzle) {
    if (substr($puz, 0, 7) eq $seven) {
        print $dt . uc(substr($puz, 8, 1)) . "\n";
    }
}
