#!/usr/bin/env perl
use strict;
use warnings;
print <<'EOH';
<style>
td, th {
    text-align: right;
}
.rt {
    text-align: right;
}
.lt {
    text-align: left;
}
.pointer {
    cursor: pointer;
}
</style>
EOH
use BeeHTML qw/
    Tr
    td
    th
    table
/;

use BeeUtil 'JON';
my ($ht, $tl, $t3, $jt, $alink_color, @words) = @ARGV;
# @words are word that have not yet been found

my $spc = '&nbsp;' x 3;

# get the HT, TL, T3, and JT tables ready
my %sums;
my %two_lets;
my %three_lets;
my @jumbled_words;
my $max_len = 0;
WORD:
for my $w (@words) {
    my $l = length($w);
    if ($max_len < $l) {
        $max_len = $l;
    }
    my $c1 = substr($w, 0, 1);
    ++$sums{$c1}{$l};

    # the summations:
    ++$sums{$c1}{1};
    ++$sums{1}{$l};
    ++$sums{1}{1};

    # the two and three letter list
    ++$two_lets{substr($w, 0, 2)} if $tl;
    ++$three_lets{substr($w, 0, 3)} if $t3;
}

my @out;

if ($ht) {
    # how many Non-zero columns and rows?
    my $ncols = 0;
    for my $l (4 .. $max_len) {
        if ($sums{1}{$l} != 0) {
            ++$ncols;
        }
    }
    my $nrows = keys(%sums) - 1;

    my $space = '&nbsp;' x 4;
    my @rows;
    my @th;
    my $dash = '&nbsp;-&nbsp;';
    push @th, th('&nbsp;');
    LEN:
    for my $l (4 .. $max_len) {
        if ($sums{1}{$l} == 0) {
            next LEN;
        }
        push @th, th("$space$l");
    }
    if ($ncols > 1) {
        push @th, th("$space&nbsp;&Sigma;");
    }
    push @rows, Tr(@th);
    CHAR:
    for my $c (sort keys %sums) {
        if ($c == 1 || $sums{$c}{1} == 0) {
            next CHAR;
        }
        my @cells;
        push @cells, th({ class => 'lt' }, $c);
        LEN:
        for my $l (4 .. $max_len) {
            if ($sums{1}{$l} == 0) {
                next LEN;
            }
            my $n = $sums{$c}{$l};
            my %attrs;
            if ($n) {
                $attrs{class} = 'rt xx';
                $attrs{onclick} = qq!issue_cmd("D$c$l")!;
            }
            else {
                $attrs{class} = 'rt';
            }
            push @cells, td(\%attrs, $n || $dash); 
        }
        if ($sums{$c}{1} != 0 && $ncols > 1) {
            push @cells, th($sums{$c}{1} || 0);
        }
        push @rows, Tr(@cells);
    }
    if ($nrows > 1) {
        @th = th({ class => 'rt' }, '&Sigma;');
        LEN:
        for my $l (4 .. $max_len) {
            if ($sums{1}{$l} == 0) {
                next LEN;
            }
            push @th, th($sums{1}{$l} || $dash);
        }
        if ($ncols > 1) {
            push @th, th($sums{1}{1} || 0);
        }
        push @rows, Tr(@th);
    }
    my $style = <<"STYLE";
<style>
.xx {
    cursor: pointer;
    color: $alink_color;
}
</style>
STYLE
    push @out, $style . table({ cellpadding => 2 }, @rows);
}
if ($tl) {
    my $two_lets = '';
    my @two = grep {
                  $two_lets{$_}
              }
              sort
              keys %two_lets;
    TWO:
    for my $i (0 .. $#two) {
        my $n = $two_lets{$two[$i]};
        if (! $n) {
            next TWO;
        }
        my $ns = $n == 1? '': "-$n";
        $two_lets .= qq!<span class='pointer' style='color: $alink_color' onclick="issue_cmd('D$two[$i]');">!
                  .  qq!$two[$i]$ns</span>!;
        if ($i < $#two
            && substr($two[$i], 0, 1) ne substr($two[$i+1], 0, 1)
        ) {
            $two_lets .= "<br>";
        }
        else {
            $two_lets .= $spc;
        }
    }
    push @out, $two_lets . '<br>';
}
if ($t3) {
    my $three_lets = '';
    my $prev = '';
    for my $w3 (sort keys %three_lets) {
        my $n = $three_lets{$w3};
        my $s = $w3;
        if ($n > 1) {
            $s .= "-$n";
        }
        my $fl = substr($s, 0, 1);  # first letter
        if ($prev && $prev ne $fl) {
            $three_lets .= "<br>";
        }
        $prev = $fl;
        $three_lets .= qq!<span class='pointer' style='color: $alink_color' onclick='issue_cmd("D-$w3")'>$s</span>$spc!
    }
    push @out, $three_lets. '<br>';
}

sub jumble {
    my ($w) = @_;
    my @chars = split '', $w;
    my $jw = '';
    while (@chars) {
        $jw .= splice @chars, int(rand(@chars)), 1;
    }
    return $jw eq $w? jumble($w): $jw;
}

sub revword {
    my ($w) = @_;
    return scalar reverse $w;
}

if ($jt) {
    my $prev_len = 0;
    # words of length 4 get 6 columns
    # words of length 5 and 6 get 3 columns
    # 7 and greater get 2 columns
    # so word of length >=5
    # will have colspan=2 or colspan=3
    my @rows;
    my @cols;
    for my $w (sort {
                   $a->[0] <=> $b->[0]
                   ||
                   $a->[1] cmp $b->[1]
               }
               map {
                   [ length $_, jumble($_), $_ ]
               }
               @words
    ) {
        my $len = $w->[0];
        if ($len != $prev_len && ($len == 6 || $len >= 8)) {
            if (@cols) {
                push @rows, Tr(@cols);
                @cols = ();
            }
            $prev_len = $len;
        }
        my $maxcol = $len <= 5? 6
                    :$len  < 8? 3
                    :           2
                    ;
        my $rw = revword($w->[2]);
        my $jw = $w->[1];
        my %attrs = (class => 'xx');
        if ($len >= 6) {
            $attrs{colspan} = $len <= 7? 2: 3;
        }
        $attrs{onclick} = qq!issue_cmd("D~$rw=$jw")!;
        push @cols, td(\%attrs, $jw);
        if (@cols == $maxcol) {
            push @rows, Tr(@cols);
            @cols = ();
        }
    }
    if (@cols) {
        push @rows, Tr(@cols);
    }
    my $style = <<"STYLE";
<style>
.xx {
    cursor: pointer;
    color: $alink_color;
}
td {
    text-align: left;
}
</style>
STYLE
    push @out, $style . table({ cellpadding => 3 }, @rows);
}

print join "-<br>", @out;
