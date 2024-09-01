#!/usr/bin/perl
use strict;
use warnings;

use File::Copy qw/
    copy
/;
use File::Slurp qw/
    read_file
    write_file
/;

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
# 3 globals
my ($type, $sort, $order);
sub col_head {
    my ($s) = @_;
    my $t = lc substr($s, 0, 4);
    $sort =~ s{\A n}{}xms;  # nwords => words
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

#
# prepare @puzzle_rows and @word_rows
#
my (@puzzle_rows, @word_rows);
open my $in, '<', 'nyt_puzzles.txt';
open my $bingo_file, '>', 'bingo_dates.txt';
my %freq;
while (my $line = <$in>) {
    chomp $line;
    my ($s, $t) = split /[|]/, $line;
    my ($date, $big_arrow, $seven, $center, @pangrams) = split ' ', $s;
    my %is_pangram = map { $_ => 1 } @pangrams;
    my (@words) = split ' ', $t;
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
    my $bingo = scalar(keys %init_let) == 0? 1: 0;
    push @puzzle_rows, {
        date      => $date,
        center    => uc $center,
        npangrams => scalar(@pangrams),
        four      => $four,
        nwords    => scalar(@words),
        score     => $score,
        bingo     => $bingo,
    };
    if ($bingo) {
        print {$bingo_file} "$date\n";
    }
    # type eq 'word'
    for my $w (@words) {
        ++$freq{$w};
    }
}
close $in;
close $bingo_file;
my $npuzzles = @puzzle_rows;
my $nwords = keys %freq;
my $s = read_file("../help.html");
$s =~ s{^\d+ \s+ puzzles \s+ with}
       {$npuzzles puzzles with}xms;
$s =~ s{^a \s+ total \s+ of \s+ \d+ \s+ different \s+ words}
       {a total of $nwords different words}xms;
write_file("../help.html", $s);

my %first_appeared;
use DB_File;
tie %first_appeared, 'DB_File', 'first_appeared.dbm';

open my $word_file, '>', '../list/words.txt';
for my $w (sort keys %freq) {
    print {$word_file} "$w\n";
    push @word_rows, {
        word   => $w,
        length => length($w),
        freq   => $freq{$w},
        first  => $first_appeared{$w},
    };
}
close $word_file;

my @files = (
    { fname => 'puzzle-date',
      sort  => sub { $a->{date} cmp $b->{date} }, },
    { fname => 'puzzle-score',
      sort  => sub { $a->{score} <=> $b->{score}
                  || $a->{date}  cmp $b->{date} }, },
    { fname => 'puzzle-four',
      sort  => sub { $a->{four} <=> $b->{four}
                  || $a->{date} cmp $b->{date} }, },
    { fname => 'puzzle-center',
      sort  => sub { $a->{center} cmp $b->{center}
                  || $a->{nwords} cmp $b->{nwords} }, },
    { fname => 'puzzle-npangrams',
      sort  => sub { $a->{npangrams} <=> $b->{npangrams}
                  || $a->{date}      cmp $b->{date} }, },
    { fname => 'puzzle-nwords',
      sort  => sub { $a->{nwords} <=> $b->{nwords}
                  || $a->{date}   cmp $b->{date} }, },
    { fname => 'puzzle-bingo',
      sort  => sub { $a->{bingo} <=> $b->{bingo}
                  || $a->{date}  cmp $b->{date} }, },
#----------------
    { fname => 'word-word',
      sort  => sub { $a->{word} cmp $b->{word} }, },
    { fname => 'word-length',
      sort  => sub { $a->{length} <=> $b->{length}
                  || $a->{word}   cmp $b->{word} } },
    { fname => 'word-freq',
      sort  => sub { $a->{freq} <=> $b->{freq}
                  || $a->{word} cmp $b->{word} } },
    { fname => 'word-first',
      sort  => sub { $a->{first} <=> $b->{first}
                  || $a->{word}  cmp $b->{word} } },
);

#
# clear the field
#
unlink <../list/*.html>;

for my $o (qw/ asc desc /) {
    $order = $o;
    for my $f (@files) {
        ($type, $sort) = split '-', $f->{fname};
        my $sort_sub = $f->{sort};
        if ($type eq 'word') {
            @word_rows = sort $sort_sub @word_rows;
            if ($order eq 'desc') {
                @word_rows = reverse @word_rows;
            }
        }
        else {
            @puzzle_rows = sort $sort_sub @puzzle_rows;
            if ($order eq 'desc') {
                @puzzle_rows = reverse @puzzle_rows;
            }
        }
        my $fname = "../list/$f->{fname}-$order.html";
        open my $out, '>', $fname;
        my $heading = $type eq 'word'? 'Words in the NYT Spelling Bee'
                     :                 'NYT Spelling Bee Puzzles';

        print {$out} <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='https://ultrabee.org/css/list.css'/>
</head>
<body>
<h1>$heading</h1>
<table cellpadding=5>
EOH
        my @th;
        if ($type eq 'puzzle') {
            push @th, th(col_head('Date')
                       . arrows('puzzle', 'date'));
            push @th, th(col_head('Center')
                       . arrows('puzzle', 'center'));
            push @th, th(col_head('Words')
                       . arrows('puzzle', 'nwords'));
            push @th, th(col_head('Pangrams')
                       . arrows('puzzle', 'npangrams'));
            push @th, th(col_head('Score')
                       . arrows('puzzle', 'score'));
            push @th, th(col_head('Four')
                       . arrows('puzzle', 'four'));
            push @th, th(col_head('Bingo')
                       . arrows('puzzle', 'bingo'));
        }
        else {
            # type eq 'word'
            push @th, th({ class => 'lf' },
                         col_head('Word')
                       . arrows('word', 'word'));
            push @th, th(col_head('Length')
                       . arrows('word', 'length'));
            push @th, th(col_head('Frequency')
                       . arrows('word', 'freq'));
            push @th, th(col_head('First Appeared')
                       . arrows('word', 'first'));
        }
        print {$out} Tr(@th), "\n";
        if ($type eq 'word') {
            for my $r (@word_rows) {
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
            for my $r (@puzzle_rows) {
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
    }
}
chdir '../list';
for my $f (<*.html>) {
    my $g = $f;
    $g =~ s{.html}{-full.html}xms;
    copy($f, $g);
    trunc($f, $g);
}
link '../../cgi-bin/nyt_puzzles.txt', 'nyt_puzzles.txt';

sub trunc {
    my ($f, $g) = @_;
    my $load = <<"EOH";
<tr>
<td colspan=10 align=center><p><a href=$g>Load the entire file.</a></td>
</tr>
EOH
    my @lines = read_file($f);
    splice(@lines, 58, -3, $load);
    write_file($f, @lines);
}
