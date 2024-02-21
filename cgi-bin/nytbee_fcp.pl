#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my %fcp_date;
tie %fcp_date, 'DB_File', 'fcp_date.dbm';
my $date = shift;
my $cp = shift;
use Date::Simple qw/
    date
/;
my $dt = date($date);
if (! $dt) {
    print "$date: invalid date";
    exit;
}
if (! -e "community_puzzles/$cp.txt") {
    print "$cp: no such community puzzle";
    exit;
}
$fcp_date{$dt->as_d8()} = $cp;
print "On $dt CP$cp will be the featured puzzle.";
