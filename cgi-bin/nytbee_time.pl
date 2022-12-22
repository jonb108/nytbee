#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp qw/
    append_file
/;
my ($min, $hour, $day, $month, $year) = (localtime(time() - 60*60))[1 .. 5];
++$month;
$year += 1900;
append_file("beelog/" . sprintf("%4d%02d%02d", $year, $month, $day),
            sprintf("%02d:%02d\n", $hour, $min));
