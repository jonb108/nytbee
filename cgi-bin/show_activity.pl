#!/usr/bin/perl
use strict;
use warnings;
no warnings 'utf8';

use CGI;
my $q = CGI->new();
print $q->header();
my $pi = $q->path_info();
$pi =~ s{\A /}{}xms;
my ($ymd, $uid) = split '/', $pi;
my $log;
if (! open $log, '<', "beelog/$ymd") {
    print "cannot open log for $ymd\n";
    exit;
}
$uid =~ s{COMMENT}{#}g;
LINE:
while (my $line = <$log>) {
    if (index($line, $uid) == 0) {
        print substr($line, length($uid)+3) . "<br>";
    }
}
