#!/usr/bin/perl
use strict;
use warnings;

use Date::Simple qw/
    date
    today
/;

# a poor man's database
use DB_File;
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';

# a poor man's CGI:
print "Content-Type: text/html; charset=ISO-8859-1\n\n";

my ($min, $hour, $day, $month) = (localtime)[ 1..4 ];
++$month;
open my $out, '>>', 'nytbee_log.txt';
printf {$out} "%02d/%02d %02d:%02d $ENV{REMOTE_ADDR} rand\n",
              $month, $day, $hour, $min;
close $out;

my $first = date('5/29/2018');
my $today = today();
my $ndays = $today - $first + 1;
while (1) {
    my $r = int(rand $ndays);
    my $dt = $first+$r;
    my $dt8 = $dt->as_d8();
    if (exists $puzzle{$dt8}) {
        print "$dt8 $puzzle{$dt8}";
        exit;
    }
}
