#!/usr/bin/perl
use strict;
use warnings;

use BeeUtil qw/
    ymd
/;
use Date::Simple qw/
    date
/;
use CGI;
use DB_File;
my %uuid_ip;
tie %uuid_ip, 'DB_File', 'uuid_ip.dbm';
my %uid_location;
tie %uid_location, 'DB_File', 'uid_location.dbm';

my $q = CGI->new();
print $q->header();
my $pi = $q->path_info();
$pi =~ s{\A /}{}xms;
my $log;
if ($pi) {
    my $dt = date($pi);
    if (! open $log, '<', 'beelog/' . $dt->format("%Y-%m-%d")) {
        print "cannot open log for $pi";
        exit;
    }
}
else {
    open $log, '<', 'beelog/' . ymd();
}
my %uid;
my $nlines = 0;
my $ngrid = 0;
my $nprog = 0;
while (my $line = <$log>) {
    ++$nlines;
    if ($line =~ m{dynamic\stable}xms) {
        ++$ngrid;
    }
    elsif ($line =~ m{\s=\s}xms) {
        ++$nprog;
    }
    my ($uid) = $line =~ m{\A (\S+)}xms;
    ++$uid{$uid};
}
print "$nlines lines<br>\n";
print "$ngrid grid<br>\n";
print "$nprog prog<br>\n";
my %locations;
for my $uid (sort keys %uid) {
    if (! exists $uid_location{$uid}) {
        for my $uuid (keys %uuid_ip) {
            if ($uuid =~ m{\A $uid}xms) {
                my $ip = $uuid_ip{$uuid};
                $ip =~ s{[|].*}{}xms;
                my $s = `curl -s https://freegeoip.app/csv/$ip`;
                my ($country, $region, $city) = (split ',', $s)[2,4,5];
                $uid_location{$uid} = "$city, $region";
                if ($country ne 'United States') {
                    $uid_location{$uid} .= ", $country";
                }
            }
        }
    }
    $locations{$uid_location{$uid}} = $uid{$uid};
}
LOC:
for my $l (sort keys %locations) {
    if ($l =~ m{\A [ ,]* \z}xms) {
        next LOC;
    }
    print "$l = $locations{$l}<br>\n";
}
