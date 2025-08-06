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
use BeeLog qw/
    open_log
/;
my $today = my_today();
my $date = shift;
my $date_obj = date($date);
my $max = shift;
my $seven = shift;
my $my_screen_name = shift;
my $bonus_mode = shift;
my $donut_mode = shift;
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
if ($bonus_mode) {
    @types = (qw/ bonus donut /);
}
elsif ($donut_mode) {
    @types = (qw/ donut bonus /);
}
for my $t (@types) {
    open my $tf, '<', "$t/$date";
    while (my $w = <$tf>) {
        chomp $w;
        ++$words{$t}{$w};
    }
    close $tf;
}
my $log = open_log($date);
LINE:
while (my $line = <$log>) {
    chomp $line;
    my ($uid, $cmd) = $line =~ m{\A (\S+)\s*(.*) \z}xms;
    next LINE if index($cmd, '= ') == -1;
        # the above will skip entries that are not for TODAY
        # because they have ~ instead of =
    $cmd = substr($cmd, 2);
    next LINE if index($cmd, 'd ') == 0;
    #next LINE if $cmd =~ m{\d}xms;
    next LINE if length($cmd) < 4;
    my @words = $cmd =~ m{\b[a-z]{4,}\b}xmsg;
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
my %boa_score;   # key: uuid, value: boa score
my %bb_score;    # key: uuid, value: bb score
for my $u (keys %tally) {
    my (%boa_lets, %bb_lets);
    for my $b (sort keys %{$tally{$u}{bonus}}) {
        my $w = $b;
        $b =~ s{[$seven]}{}xmsg;
        my $a = substr($b, 0, 1);
        $boa_lets{$a}++;
        ++$bb_lets{substr($w, 0, 1)};
    }
    $boa_score{$u} = scalar(keys %boa_lets);
    $bb_score{$u}  = scalar(keys %bb_lets);
}
# and OW values for each
my %only;   # keys: uuid, type
            # value: ow score for the person for the type
for my $u (keys %tally) {
    for my $t (@types) {
        for my $w (keys %{$tally{$u}{$t}}) {
            if ($words{$t}{$w} == 1) {
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
if ($donut_mode) {
    @arr = qw/
        donut 1
        bonus 2
    /;
}
my %order = @arr;
my %name = reverse @arr;
    # this hash happens to be one-to-one...
    # so it is reversible
my @counts;
for my $u (keys %tally) {
    for my $t (@types) {
        my $n = scalar keys %{$tally{$u}{$t}};
        if ($n) {
            push @counts, [ $u, $order{$t}, $n,
                            $only{$u}{$t}, $boa_score{$u}, $bb_score{$u} ];
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
    text-align: right;
}
</style>
EOH
if ($date_obj ne $today) {
    print "Final results for " . $date_obj->format("%D") . ":<p>\n";
}
# Big hack.  Needs rethinking.
my $sp = '&nbsp;' x 2;
my $ow_printed = 0;
print "<table cellpadding=0 border=0>\n";
for my $aref (sort {
                  $a->[1] <=> $b->[1]
                  ||
                  $b->[2] <=> $a->[2]
                  || 
                  $b->[3] <=> $a->[3]
                  ||
                  $b->[4] <=> $a->[4]
                  ||
                  $b->[5] <=> $a->[5]
                  ||
                  $a->[0] cmp $b->[0]
              } @counts
) {
    my ($uid, $type, $n) = @$aref;
    if ($type ne $prev) {
        #my $colspan = ($type != 1)? 3: 2;
        my $colspan = 2;
        print "<tr><td colspan=$colspan class='lt head'>"
            . ucfirst $name{$type}
            . "</td>";
        if ($donut_mode || ($type != 3 && ! $ow_printed)) {
            print "<td class=entry>#</td>"
                . "<td>${sp}ow</td>";
            $ow_printed = 1;

        }
        if (($donut_mode && $type == 2) || (! $donut_mode && $type == 1)) {
            print "<td>${sp}boa</td>"
                . "<td>${sp}bb</td>"
                ;
        }
        elsif ($type == 2 && $donut_mode) {
            print "<td>#</td>"
                . "<td>${sp}ow</td>"
                ;
        }
        print "</tr>\n";
        $prev = $type;
    }
    ++$tot{$type};
    if ($tot{$type} <= $max) {
        my $sn = $uuid_screen_name{$uid};
        my $star = ($sn eq $my_screen_name)? "<td style='text-align: left; color: red; font-size: 20pt;'>&nbsp;*</td>": '';
        print "<tr><td>&nbsp;&nbsp;</td><td class='lt entry'>$sn</td><td class=entry>$sp$n</td>";
        print "<td class=entry>&nbsp;&nbsp;$only{$uid}{$name{$type}}</td>";
        if (($donut_mode && $type == 2) || (! $donut_mode && $type == 1)) {
            print "<td class=entry>$boa_score{$uid}</td>";
            print "<td class=entry>$bb_score{$uid}</td>" if $bb_score{$uid};
        }
        print "$star</tr>\n";
    }
}
print "</table>\n";
