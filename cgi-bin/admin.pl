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
# the above has keys of the uuid and value of 'ip address | details of browser'
# the browser details are filled in when the uuid is first encountered
my %uid_location;
tie %uid_location, 'DB_File', 'uid_location.dbm';

my $q = CGI->new();
print $q->header();
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
my %data;
    # a hash of hashes
    # key $uid
    # then grid, prog, nr, dt, cp, hint, rank, city, state, country
    #      #     #     #   #   #   #     str   str   str    str
    # city, state, country are filled in after
    # processing the lines in the beelog/ file.

# totals across uid
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
    if ($line =~ m{dyntab}xms) {
        ++$ngrid;
        ++$data{$uid}{grid};
        if ($line =~ m{: \s+ [a-z]+ \s* \z}xms) {
            ++$n_single_grid;
        }
        elsif ($line =~ m{dyntab\s+suggestion}xms) {
            ++$n_suggest;
        }
    }
    elsif ($line =~ m{\s=\s}xms) {
        ++$nprog;
        ++$data{$uid}{prog};
        my $href = $data{$uid};
        if ($line =~ m{=\srank(\d+)}xms) {
            $href->{rank} .= "$rank[$1] ";
        }
        elsif ($line =~ m{=\snr}xms) {
            ++$href->{nr};
        }
        elsif ($line =~ m{=\s(\d.*\d)}xms && $1 ne '51' && $1 ne '52') {
            # a dated puzzle
            ++$href->{dt};
        }
        elsif ($line =~ m{=\s(cp\d+)}xms) {
            $href->{cp} .= "$1 ";
        }
        elsif (   $line =~ m{=\sd   (p|[a-z][a-z]|[a-z]\d+|r|r5)\s*\z}xms
               || $line =~ m{=\sv\d+(p|[a-z][a-z]|[a-z]\d+)          }xms
               || $line =~ m{=\se\d+(p|[a-z][a-z]|[a-z]\d+)          }xms
               || $line =~ m{=\sht\s*$                               }xms
               || $line =~ m{=\stl\s*$                               }xms
               || $line =~ m{=\sg\s+yp?\s*$                             }xms
               ) {
            ++$href->{hint};
        }
        elsif ($line =~ m{=\s[*](donut|lexicon|bonus)}xms) {
            ++$href->{$1};
        }
    }
}
print <<'EOH';
<html>
<head>
<meta charset="utf-8">
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
.blue {
    color: blue;
}
</style>
</head>
<body>
EOH
print "$ymd";
sub prev {
    if (-f "beelog/$prev") {
        print " <a href=https://logicalpoetry.com/cgi-bin/admin.pl/$prev>Previous</a>";
    }
    print "<br>";
}
prev();
print "$nlines lines<br>\n";
print "$nprog prog<br>\n";
print "$ngrid grid<br>\n";
print "$n_single_grid single grid<br>\n";
print "$n_suggest grid suggestions<br>\n";
print "-------------<br>\n";
UID:
for my $uid (keys %data) {
    my $href = $data{$uid};
    if (! exists $uid_location{$uid}) {
        for my $uuid (keys %uuid_ip) {
            # this is inefficient but we don't put the full
            # uuid in the log... just 11 chars
            if ($uuid =~ m{\A $uid}xms) {
                my $ip = $uuid_ip{$uuid};
                $ip =~ s{[|].*}{}xms;
                my $s = `curl -s http://api.ipstack.com/$ip?access_key=$access_key`;
                $s = Encode::encode('ISO-8859-1', $s);
                my $hrf;
                eval {
                    $hrf = decode_json($s);
                };
                if ($@) {
                    JON "lookup failure: $uid and $s";
                    next UID;
                }
                my $city = $hrf->{city};
                my $region = $hrf->{region_name};
                my $country = $hrf->{country_name};
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
    if ($s && $s =~ m{\A([^,]*),([^,]*),\s*(.*)\z}xms) {
        # non-US
        my ($city, $state, $country) = ($1, $2, $3);
        if ($state !~ /\S/ || $city !~ /\S/) {
            next UID;
        }
        # fix up UTF-8 chars or ...?  I don't understand
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
        $href->{city} = $city;
        $href->{state} = $state;
        $href->{country} = $country;
    }
    else {
        my ($city, $state) = split ',', $s;
        if ($state !~ /\S/ || $city !~ /\S/) {
            next UID;
        }
        $href->{city} = $city;
        $href->{state} = $state;
        $href->{country} = '';
    }
}

sub show_data {
    my ($uid) = @_;
    my $href = $data{$uid};
    my $act = "https://logicalpoetry.com/cgi-bin/show_activity.pl/$ymd/$uid";
    if ($href->{country}) {
        print "<a class=green href=$act>$href->{country}</a>, $href->{state}, $href->{city}";
    }
    else {
        print "<a class=green href=$act>$href->{state}</a>, $href->{city}";
    }
    print " ";
    if ($href->{grid}) {
        print "g$href->{grid}";
    }
    if ($href->{prog}) {
        print "p$href->{prog} ";
    }
    if ($href->{hint}) {
        print " <span class=purple>h$href->{hint}</span>";
    }
    if ($href->{donut} || $href->{lexicon} || $href->{bonus}) {
        print "<span class=blue>"
            . "D" . ($href->{donut}||'')
            . "L" . ($href->{lexicon}||'')
            . "B" . ($href->{bonus}||'')
            . "</span>"
            ;
    }
    if ($href->{nr}) {
        print "<span class=red>nr$href->{nr}</span>";
    }
    if ($href->{cp}) {
        # community puzzles
        print " <span class=red>$href->{cp}</span>";
    }
    if ($href->{dt}) {
        # dated puzzles
        print "<span class=red>dt$href->{dt}</span>";
    }
    if ($href->{rank}) {
        print " $href->{rank}";
    }
    print "<br>\n";
}
my @non_us = grep { $data{$_}{country} } keys %data;
for my $uid (
    map {
       $_->[0]
    }
    sort {
       $a->[1] cmp $b->[1]
       ||
       $a->[2] cmp $b->[2]
       ||
       $a->[3] cmp $b->[3]
    }
    map {
       my $href = $data{$_};
       [ $_, $href->{country}, $href->{state}, $href->{city} ]
    }
    @non_us
) {
    show_data($uid);
}
print "-------------<br>\n";
my @us = grep { !$data{$_}{country} } keys %data;
for my $uid (
    map {
       $_->[0]
    }
    sort {
       $a->[1] cmp $b->[1]
       ||
       $a->[2] cmp $b->[2]
    }
    map {
       my $href = $data{$_};
       [ $_, $href->{state}, $href->{city} ]
    }
    @us
) {
    show_data($uid);
}
prev();
