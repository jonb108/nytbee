#!/usr/bin/perl
# SO hacky :(
use strict;
use warnings;
no warnings 'utf8';

use BeeUtil qw/
    ymd
    JON
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
my $prev = (date($ymd)-1)->format("%Y-%m-%d");
if (! open $log, '<', "beelog/$ymd") {
    print "cannot open log for $ymd\n";
    exit;
}
my %uid;
my %g_uid;
my %p_uid;
my %nr_uid;
my %dt_uid;
my %cp_uid;
my %rk_uid;     # rank achieved
my %ht_uid;     # hints d(p|[a-z][a-z]|[a-z]\d+)
                #       v\d+(p|[a-z][a-z]|[a-z]\d+)
                #       e\d+(p|[a-z][a-z]|[a-z]\d+)
                #       dr
                #       dr5
                #       1
                #       2
                #       51
                #       52
                #       ht
                #       tl
my $nlines = 0;
my $ngrid = 0;
my $n_single_grid = 0;
my $n_suggest = 0;
my $nprog = 0;
my @rank;
$rank[7] = 'AM';
$rank[8] = 'GN';
$rank[9] = 'QB';
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
        if ($line =~ m{=\srank(\d+)}xms) {
            $rk_uid{$uid} .= "$rank[$1] ";
        }
        elsif ($line =~ m{=\snr}xms) {
            ++$nr_uid{$uid};
        }
        elsif ($line =~ m{=\s(\d.*\d)}xms && $1 ne '51' && $1 ne '52') {
            # a dated puzzle
            ++$dt_uid{$uid};
        }
        elsif ($line =~ m{=\s(cp\d+)}xms) {
            $cp_uid{$uid} .= "$1 ";
        }
        elsif (   $line =~ m{=\sd   (p|[a-z][a-z]|[a-z]\d+|r|r5)\s*\z}xms
               || $line =~ m{=\sv\d+(p|[a-z][a-z]|[a-z]\d+)          }xms
               || $line =~ m{=\se\d+(p|[a-z][a-z]|[a-z]\d+)          }xms
               || $line =~ m{=\sht\s*$                               }xms
               || $line =~ m{=\stl\s*$                               }xms
               ) {
            ++$ht_uid{$uid};
        }
    }
}
print <<'EOH';
<html>
<head>
<meta charset="UTF-8">
<style>
body {
    font-size: 18pt;
    margin: .5in;
}
.red {
    color: red;
}
.green {
    color: green;
}
.purple {
    color: purple;
}
a {
    text-decoration: none;
    color: blue;
}
</style>
</head>
<body>
EOH
print "$ymd";
if (-f "beelog/$prev") {
    print " <a href=https://logicalpoetry.com/cgi-bin/admin.pl/$prev>Previous</a>";
}
print "<br>\n";
print "$nlines lines<br>\n";
print "$nprog prog<br>\n";
print "$ngrid grid<br>\n";
print "$n_single_grid single grid<br>\n";
print "$n_suggest grid suggestions<br>\n";
print "-------------<br>\n";
my @data;
UID:
for my $uid (sort keys %uid) {
    if (! exists $uid_location{$uid}) {
        for my $uuid (keys %uuid_ip) {
            if ($uuid =~ m{\A $uid}xms) {
                my $ip = $uuid_ip{$uuid};
                $ip =~ s{[|].*}{}xms;
                my $s = `curl -s http://api.ipstack.com/$ip?access_key=$access_key`;
                $s = Encode::encode('ISO-8859-1', $s);
                my $href;
                eval {
                    $href = decode_json($s);
                };
                if ($@) {
                    JON "lookup failure: $uid and $s";
                    next UID;
                }
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
    my $s = $uid_location{$uid};
    if ($s && $s =~ m{\A([^,]*),([^,]*),(.*)\z}xms) {
        my ($city, $state, $country) = ($1, $2, $3);
        if ($state !~ /\S/ || $city !~ /\S/) {
            next UID;
        }
        if ($country =~ m{Canada}) {
            if ($city =~ m{Montr.*al}xms) {
                $city = 'Montreal';
            }
            elsif ($city =~ m{Qu.*ec}xms) {
                $city = $state = 'Quebec';
            }
        }
        elsif ($country =~ m{Sweden}xms) {
            if ($state =~ m{sterg.*tland}xms) {
                $state = 'Ostergotland';
            }
            if ($city =~ m{link.*ping}xmsi) {
                $city = 'Linkoping';
            }
        }
        elsif ($country =~ m{Switzerland}xms) {
            if ($state =~ m{Neuch}xms) {
                $state = $city = 'Neuchatel';
            }
            if ($city =~ m{\AZ.*rich\z}xmsi) {
                $city = 'Zurich';
            }
        }
        elsif ($country =~ m{Iceland}xms) {
            if ($city =~ m{Reykjav}xms) {
                $city = 'Reykjavik';
            }
        }
        elsif ($country =~ m{France}xms) {
            if ($state =~ m{-de-France}xms) {
                $state = 'Ile-de-France';
            }
            if ($state =~ m{Prov.*d'Azur}xms) {
                $state = "Provence-Alpes-Cote d'Azur";
            }
            if ($state =~ m{Auvergne-Rh.*ne-Alpes}xms) {
                $state = 'Auvergne-Rhone-Alpes';
            }
        }
        elsif ($country =~ m{Germany}xms) {
            if ($city =~ m{Unterschlei.*heim}xms) {
                $city = 'Unterschleissheim';
            }
            elsif ($state =~ m{Baden.*berg}xms) {
                $state = 'Baden-Wurtemberg'
            }
        }
        elsif ($country =~ m{Brazil}xms) {
            if ($city =~ m{S.*Paulo}xms) {
                $city = $state = 'Sao Paulo';
            }
        }
        elsif ($country =~ m{Czechia}xms) {
            if ($city =~ m{Olomouc}xms) {
                $city = $state = 'Olomouc';
            }
            elsif ($city =~ m{Brand.*nad.*labem.*slav}xmsi) {
                $city = 'Brandys nad Labem-Stara Boleslav';
            }
        }
        push @data, [ $city, $state, $country,
                      $g_uid{$uid}, $p_uid{$uid}, $nr_uid{$uid}, $cp_uid{$uid}, $dt_uid{$uid}, $ht_uid{$uid}, $rk_uid{$uid} ];
    }
    else {
        my ($city, $state) = split ',', $s;
        if ($state !~ /\S/ || $city !~ /\S/) {
            next UID;
        }
        push @data, [ $city, $state, '',
                      $g_uid{$uid}, $p_uid{$uid}, $nr_uid{$uid}, $cp_uid{$uid}, $dt_uid{$uid}, $ht_uid{$uid}, $rk_uid{$uid} ];
    }
}
my @non_us = grep { $_->[2] } @data;
for my $d (sort {
               $a->[2] cmp $b->[2]
               ||
               $a->[1] cmp $b->[1]
               ||
               $a->[0] cmp $b->[0]
           }
           @non_us
) {
    print "<span class=green>$d->[2]</span>, $d->[1], $d->[0] =>";
    if ($d->[3]) {
        print " g $d->[3]";
    }
    if ($d->[4]) {
        print " p $d->[4]";
    }
    if ($d->[8]) {
        print " <span class=purple>h $d->[8]</span>";
    }
    if ($d->[5]) {
        print " <span class=red>nr $d->[5]</span>";
    }
    if ($d->[6]) {
        # community puzzles
        print " <span class=red>$d->[6]</span>";
    }
    if ($d->[7]) {
        # dated puzzles
        print " <span class=red>dt $d->[7]</span>";
    }
    if ($d->[9]) {
        print " $d->[9]";
    }
    print "<br>\n";
}
print "-------------<br>\n";
my @us = grep { !$_->[2] } @data;
for my $d (sort {
               $a->[1] cmp $b->[1]
               ||
               $a->[0] cmp $b->[0]
           }
           @us
) {
    print "<span class=green>$d->[1]</span>, $d->[0] =>";
    if ($d->[3]) {
        print " g $d->[3]";
    }
    if ($d->[4]) {
        print " p $d->[4]";
    }
    if ($d->[8]) {
        print " <span class=purple>h $d->[8]</span>";
    }
    if ($d->[5]) {
        print " <span class=red>nr $d->[5]</span>";
    }
    if ($d->[6]) {
        # community puzzles
        print " <span class=red>$d->[6]</span>";
    }
    if ($d->[7]) {
        # dated puzzles
        print " <span class=red>dt $d->[7]</span>";
    }
    if ($d->[9]) {
        print " $d->[9]";
    }
    print "<br>\n";
}
if (-f "beelog/$prev") {
    print "<a href=https://logicalpoetry.com/cgi-bin/admin.pl/$prev>Previous</a><br>";
}
