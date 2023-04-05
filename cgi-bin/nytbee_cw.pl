#!/usr/bin/perl
use warnings;
use strict;
use Data::Dumper;
use DB_File;
my %uuid_screen_name;   # hash key: uid, value: 
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
use Date::Simple qw/
    date
    today
/;
use BeeUtil qw/
    my_today
    JON
/;
my $today = my_today();
my $date = shift;
my $date_obj = date($date);
my $max = shift;
my $seven = shift;
my %words;  # hash of hash
            # keys: donut/lexicon/bonus, word
            # value: count of how many times the word was found
            #       Note - if someone deletes a word
            #              with the minus (- dash) prefix
            #              and then re-adds the word
            #              the count will be off...
            #              this will be rare
 
my %tally;  # hash of hash of hash
            # keys: uid, donut/lexicon/bonus, word
            # value: 1
my @types = qw/ donut lexicon bonus /;
for my $t (@types) {
    open my $tf, '<', "$t/$date";
    while (my $w = <$tf>) {
        chomp $w;
        ++$words{$t}{$w};
    }
    close $tf;
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
# we have all the information we need
# about who found what words.
# next figure out BOA values for each person
my %boa_score;   # key: uuid
                 # value: boa score
for my $u (keys %tally) {
    my %boa_lets;
    for my $b (keys %{$tally{$u}{bonus}}) {
        $b =~ s{[$seven]}{}xmsg;
        $boa_lets{substr($b, 0, 1)}++;
    }
    $boa_score{$u} = scalar(keys %boa_lets);
}
# and OW values for each
my %only;   # keys: uuid, type
            # value: ow score for the person for the type
for my $u (keys %tally) {
    for my $t (@types) {
        for my $w (keys %{$tally{$u}{$t}}) {
            if ($words{$t}{$w} == 1) {
if ($u eq 'sahadev108!') { JON "$t $w"}
                $only{$u}{$t}++;
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
my %name = reverse @arr;
    # this hash happens to be one-to-one...
    # so it is reversible
my @counts;
for my $u (keys %tally) {
    for my $t (@types) {
        my $n = scalar keys %{$tally{$u}{$t}};
        if ($n) {
            push @counts, [ $u, $order{$t}, $n ];
        }
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
    font-size: 18pt;
}
.entry {
    font-size: 16pt;
}
</style>
EOH
if ($date_obj ne $today) {
    print "Final results for " . $date_obj->format("%D") . ":<p>\n";
}
my $sp = '&nbsp;' x 2;
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
        if ($type == 1) {
            print "<tr>"
                . ("<td>&nbsp;</td>" x 2)
                . "<td>#</td>"
                . "<td>${sp}ow</td>"
                . "<td>${sp}boa</td>"
                . "</tr>\n";
        }
        $prev = $type;
    }
    ++$tot{$type};
    if ($tot{$type} <= $max) {
        print "<tr><td>&nbsp;</td><td class='lt entry'>$uuid_screen_name{$uid}</td><td class=entry>$sp$n</td>";
        print "<td class=entry>$only{$uid}{$name{$type}}</td>";
        if ($type == 1) {
            print "<td class=entry>$boa_score{$uid}</td>";
        }
        print "</tr>\n";
    }
}
print "</table>\n";
