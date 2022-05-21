#!/usr/bin/perl
use strict;
use warnings;
no warnings 'utf8';

use BeeUtil qw/
    ymd
/;
use Date::Simple qw/
    date
/;
use Encode qw/
    encode_utf8
/;
use JSON qw/
    decode_json
/;
my $access_key = 'ac1e43f492eddfe68736c4f4fb388e92';

use CGI;
use DB_File;
my %uuid_ip;
tie %uuid_ip, 'DB_File', 'uuid_ip.dbm';
my %uid_location;
tie %uid_location, 'DB_File', 'uid_location.dbm';

my $q = CGI->new();
print $q->header(-charset => 'utf-8');
my $pi = $q->path_info();
$pi =~ s{\A /}{}xms;
my $log;
my $ymd;
if ($pi) {
    my $dt = date($pi);
    $ymd = $dt->format("%Y-%m-%d");
}
else {
    $ymd = ymd();
}
if (! open $log, '<', "beelog/$ymd") {
    print "cannot open log for $ymd\n";
    exit;
}
my %uid;
my %g_uid;
my %p_uid;
my $nlines = 0;
my $ngrid = 0;
my $n_single_grid = 0;
my $n_suggest = 0;
my $nprog = 0;
LINE:
while (my $line = <$log>) {
    if ($line =~ m{new\s+puzzle}xms) {
        next LINE;
    }
    ++$nlines;
    my ($uid) = $line =~ m{\A (\S+)}xms;
    ++$uid{$uid};
    if ($line =~ m{dyntab}xms) {
        ++$ngrid;
        ++$g_uid{$uid};
        if ($line =~ m{: \s+ [a-z]+ \s* \z}xms) {
            ++$n_single_grid;
        }
        elsif ($line =~ m{dyntab\s+suggestion}xms) {
            ++$n_suggest;
        }
    }
    elsif ($line =~ m{\s=\s}xms) {
        ++$nprog;
        ++$p_uid{$uid};
    }
}
print <<'EOH';
<style>
body {
    font-size: 18pt;
    margin: .5in;
}
.red {
    color: red;
}
</style>
EOH
print "$ymd<br>\n";
print "$nlines lines<br>\n";
print "$nprog prog<br>\n";
print "$ngrid grid<br>\n";
print "$n_single_grid single grid<br>\n";
print "$n_suggest grid suggestions<br>\n";
my @data;
for my $uid (sort keys %uid) {
    if (! exists $uid_location{$uid}) {
        for my $uuid (keys %uuid_ip) {
            if ($uuid =~ m{\A $uid}xms) {
                my $ip = $uuid_ip{$uuid};
                $ip =~ s{[|].*}{}xms;
                my $s = `curl -s http://api.ipstack.com/$ip?access_key=$access_key`;
                $s = Encode::encode('ISO-8859-1', $s);
                my $href = decode_json($s);
                my $city = $href->{city};
                my $region = $href->{region_name};
                my $country = $href->{country_name};
                my $ss = "$city, $region";
                if ($country ne 'United States') {
                    $ss .= ", $country";
                }
                eval {
                    $uid_location{$uid} = $ss;
                };
                if ($@) {
                    $uid_location{$uid} = '??';
                }
            }
        }
    }
    push @data, [ $uid, $uid_location{$uid}, $g_uid{$uid}, $p_uid{$uid} ];
}
for my $d (sort { $a->[1] cmp $b->[1] } @data) {
    my $loc = $d->[1];
    if ($loc =~ m{,.*,}xms) {
        $loc = "<span class=red>$loc</span>";
    }
    print "$loc => g $d->[2] p $d->[3]<br>\n";
}
my $prev = (date($ymd)-1)->format("%Y-%m-%d");
if (-f "beelog/$prev") {
    print "<a href=https://logicalpoetry.com/cgi-bin/admin.pl/$prev>Previous</a><br>";
}
