#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
use DB_File;
my %uid_location;   # hash key: uid, value: 
tie %uid_location, 'DB_File', 'uid_location.dbm';
my $date = shift;
my $max = shift || 5;
my %words;  # hash of hash
            # keys: donut/lexicon/bonus, word = value: 1
my %tally;  # hash of hash of hash
            # keys: uid, donut/lexicon/bonus, word = value: 1
my @types = qw/ donut lexicon bonus /;
for my $e (@types) {
    open my $ef, '<', "$e/$date";
    while (my $w = <$ef>) {
        chomp $w;
        $words{$e}{$w} = 1;
    }
    close $ef;
}
open my $log, '<', "beelog/$date";
LINE:
while (my $line = <$log>) {
    chomp $line;
    my ($uid, $cmd) = $line =~ m{\A (\S+)\s*(.*) \z}xms;
    next LINE if index($cmd, '= ') == -1;
    $cmd = substr($cmd, 2);
    next LINE if index($cmd, 'd ') == 0;
    next LINE if $cmd =~ m{\d}xms;
    next LINE if length($cmd) < 4;
    my @words = $cmd =~ m{[a-z]{4,}}xmsg;
    WORD:
    for my $w (@words) {
        for my $t (@types) {
            if (exists $words{$t}{$w}) {
                $tally{$uid}{$t}{$w} = 1;
                next WORD;
            }
        }
    }
}
my @arr = qw/
    bonus   1
    donut   2
    lexicon 3
/;
my %order = @arr;
# how to get key-value from a hash?
my %name = reverse @arr;
my @counts;
for my $u (keys %tally) {
    for my $e (@types) {
        push @counts, [ $u, $order{$e}, scalar keys %{$tally{$u}{$e}} ];
    }
}
my %tot;
my $prev = '';
print <<'EOH';
<style>
.lt {
    text-align: left;
}
.head {
    font-weight: bold;
    font-size: 16pt;
}
.entry {
    font-size: 14pt;
}
</style>
EOH
print "<table cellpadding=0>\n";
for my $aref (sort {
                  $a->[1] <=> $b->[1]
                  ||
                  $b->[2] <=> $a->[2]
                  ||
                  $a->[0] cmp $b->[0]
              } @counts
) {
    my ($uid, $type, $n) = @$aref;
    if ($type ne $prev) {
        print "<tr><td colspan=3 class='lt head'>"
            . ucfirst $name{$type}
            . "</td></tr>\n";
        $prev = $type;
    }
    ++$tot{$type};
    if ($tot{$type} <= $max) {
        print "<tr><td>&nbsp;</td><td class='lt entry'>$uid_location{$uid}</td><td class=entry>$n</td></tr>\n";
    }
}
print "</table>\n";
