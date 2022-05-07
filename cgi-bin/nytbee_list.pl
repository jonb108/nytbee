#!/usr/bin/perl
use strict;
use warnings;
use BeeUtil qw/
    word_score
    uniq_chars
    Tr
    th
    td
/;

sub add_dashes {
    # yyyymmdd
    my ($d) = @_;
    return substr($d, 0, 4)
         . '-'
         . substr($d, 4, 2)
         . '-'
         . substr($d, 6, 2)
         ;

}

#
# type: 'puzzle ' or 'word'
# sort: if type is 'puzzle' - date, score, four, center,
#                             npangrams, nwords, bingo
#       if type is 'word'   - word, length, freq, first
# order: 'asc' or 'desc'
#
sub usage {
    die <<'EOF';
nytbee_list.pl puzzle  date|score|four|center|npangrams|nwords|bingo  asc|desc
OR
nytbee_list.pl word    word|length|freq|first  asc|desc
EOF
}
if (@ARGV != 3) {
    usage;
}
my ($type, $sort, $order) = @ARGV;
usage unless $type =~ m{\A puzzle|word \z}xms;
usage if
    $type eq 'puzzle' 
    && $sort !~ m{\A date|score|four|center|npangrams|nwords|bingo \z}xms;
usage if
    $type eq 'word' 
    && $sort !~ m{\A word|length|freq|first \z}xms;
usage unless $order =~ m{\A asc|desc \z}xms;

my $fname = "../nytbee/list/$type-$sort-$order.html";
if (-f $fname) {
    exit;
}
open my $out, '>', $fname;
my $heading = $type eq 'word'? 'Words in the NYT Spelling Bee'
             :                 'NYT Spelling Bee Puzzles';
        
print {$out} <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='https://logicalpoetry.com/nytbee/css/list.css'/>
</head>
<body>
<h1>$heading</h1>
<table cellpadding=5>
EOH
sub col_head {
    my ($s) = @_;
    my $t = lc substr($s, 0, 4);
    my $color = $t eq substr($sort, 0, 4)? "green": "black";
    return "<span class=$color>$s</span>";
}
sub arrows {
    my ($ptype, $psort) = @_;
    my ($c_up, $c_down);
    if ($ptype ne $type) {
        $c_up = $c_down = 'black';
    }
    else {
        $c_up   = $order eq 'asc'  && $psort eq $sort? 'red': 'black';
        $c_down = $order eq 'desc' && $psort eq $sort? 'red': 'black';
    }
    return "<a class=$c_up href=$ptype-$psort-asc.html>&#9650;</a>"
         . "<a class=$c_down href=$ptype-$psort-desc.html>&#9660;</a>"
}
my @th;
if ($type eq 'puzzle') {
    push @th, th(col_head('Date') . arrows('puzzle', 'date'));
    push @th, th(col_head('Center') . arrows('puzzle', 'center'));
    push @th, th(col_head('Words') . arrows('puzzle', 'nwords'));
    push @th, th(col_head('Pangrams') . arrows('puzzle', 'npangrams'));
    push @th, th(col_head('Score') . arrows('puzzle', 'score'));
    push @th, th(col_head('Four') . arrows('puzzle', 'four'));
    push @th, th(col_head('Bingo') . arrows('puzzle', 'bingo'));
}
else {
    # type eq 'word'
    push @th, th({ class => 'lf' }, col_head('Word') . arrows('word', 'word'));
    push @th, th(col_head('Length') . arrows('word', 'length'));
    push @th, th(col_head('Frequency') . arrows('word', 'freq'));
    push @th, th(col_head('First Appeared') . arrows('word', 'first'));
}
print {$out} Tr(@th), "\n";
open my $in, '<', 'nyt_puzzles.txt';
my (%freq, %first);
my @rows;
while (my $line = <$in>) {
    chomp $line;
    my ($s, $t) = split /[|]/, $line;
    my ($date, $big_arrow, $seven, $center, @pangrams) = split ' ', $s;
    my %is_pangram = map { $_ => 1 } @pangrams;
    my (@words) = split ' ', $t;
    if ($type eq 'puzzle') {
        my $score = 0;
        my $four = 0;
        my %init_let = map { $_ => 1 } split //, $seven;
        for my $w (@words) {
            $score += word_score($w, $is_pangram{$w});
            ++$four if length($w) == 4;
            my $c1 = substr($w, 0, 1);
            if ($init_let{$c1}) {
                delete $init_let{$c1};
            }
        }
        push @rows, {
            date      => $date,
            center    => uc $center,
            npangrams => scalar(@pangrams),
            four      => $four,
            nwords    => scalar(@words),
            score     => $score,
            bingo     => scalar(keys %init_let) == 0? 1: 0,
        };
    }
    else {
        # type eq 'word'
        for my $w (@words) {
            ++$freq{$w};
            if (! $first{$w}) {
                $first{$w} = $date;
            }
        }
    }
}
close $in;

if ($type eq 'word') {
    for my $w (keys %freq) {
        push @rows, {
            word   => $w,
            length => length($w),
            freq   => $freq{$w},
            first  => $first{$w},
        };
    }
    if ($sort eq 'word') {
        @rows = sort { $a->{word} cmp $b->{word} } @rows;
    }
    elsif ($sort eq 'length') {
        @rows = sort {
                    $a->{length} <=> $b->{length}
                    ||
                    $a->{word}   cmp $b->{word}
                } @rows;
    }
    elsif ($sort eq 'freq') {
        @rows = sort {
                    $a->{freq} <=> $b->{freq}
                    ||
                    $a->{word}   cmp $b->{word}
                } @rows;
    }
    elsif ($sort eq 'first') {
        @rows = sort {
                    $a->{first} <=> $b->{first}
                    ||
                    $a->{word}   cmp $b->{word}
                } @rows;
    }
    if ($order eq 'desc') {
        @rows = reverse @rows;
    }
    for my $r (@rows) {
        my $W = uc $r->{word};
        my $lW = $r->{length};
        print {$out} Tr(
            ($lW >= 7 && uniq_chars($W) == 7)?
                  $lW == 7? td({ class => 'perfect_pg_color'}, $W)
                 :          td({ class => 'pg_color'}, $W)
                : td($W), 
            td({class => 'rt'}, $r->{length}),        
            td({class => 'rt'}, $r->{freq}),        
            td({class => 'cn'}, add_dashes($r->{first})),        
        ), "\n";
    }
}
else {
    if ($sort eq 'date') {
        @rows = sort {
                    $a->{date} cmp $b->{date}
                } @rows;
    }
    elsif ($sort eq 'score') {
        @rows = sort {
                    $a->{score} <=> $b->{score}
                    ||
                    $a->{date} cmp $b->{date}
                } @rows;
    }
    elsif ($sort eq 'four') {
        @rows = sort {
                    $a->{four} <=> $b->{four}
                    ||
                    $a->{date} cmp $b->{date}
                } @rows;
    }
    elsif ($sort eq 'center') {
        @rows = sort {
                    $a->{center} cmp $b->{center}
                    ||
                    $a->{nwords} <=> $b->{nwords}
                } @rows;
    }
    elsif ($sort eq 'npangrams') {
        @rows = sort {
                    $a->{npangrams} <=> $b->{npangrams}
                    ||
                    $a->{date} cmp $b->{date}
                } @rows;
    }
    elsif ($sort eq 'nwords') {
        @rows = sort {
                    $a->{nwords} <=> $b->{nwords}
                    ||
                    $a->{date} cmp $b->{date}
                } @rows;
    }
    elsif ($sort eq 'bingo') {
        @rows = sort {
                    $a->{bingo} <=> $b->{bingo}
                    ||
                    $a->{date} cmp $b->{date}
                } @rows;
    }
    if ($order eq 'desc') {
        @rows = reverse @rows;
    }
    for my $r (@rows) {
        print {$out} Tr(
            td({ class => 'cn' }, add_dashes($r->{date})),
            td({ class => 'cn' }, $r->{center}),
            td({ class => 'rt' }, $r->{nwords}),
            td({ class => 'rt' }, $r->{npangrams}),
            td({ class => 'rt' }, $r->{score}),
            td({ class => 'rt' }, $r->{four}),
            td({ class => 'cn' }, $r->{bingo}),
        ), "\n";
    }
}
print {$out} <<'EOH';
</table>
</body>
</html>
EOH
close $out;
