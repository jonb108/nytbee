#!/usr/bin/perl
use strict;
use warnings;
use v5.10;

my $pdate = shift;
my $game;
open my $in, '<', '../cgi-bin/nyt_puzzles.txt';
LINE:
while (my $line = <$in>) {
    chomp $line;
    if ($line =~ m{\A $pdate}xms) {
        $game = $line;
        last LINE;
    }
}
close $in;

my ($s, $t) = split m/\|/, $game;
my ($date, $arrow, $seven, $center, @pangrams) = split ' ', $s;
my %is_pangram = map { $_ => 1 } @pangrams;
my $npangrams = @pangrams;
my (@words) = split ' ', $t;
my $nwords = @words;
my @seven = map { uc } split //, $seven;
my %first;
for my $w (@words) {
    ++$first{substr($w, 0, 1)};
}
my $bingo = keys %first == 7? 1: 0;
sub word_score {
    my ($w) = @_;
    my $lw = length($w);
    return ($lw == 4? 1: $lw) + ($is_pangram{$w}? 7: 0);
}
my $max_score = 0;
for my $w (@words) {
    $max_score += word_score($w);
}
my @found = @ARGV;
my $nfound = @found;
my $score = 0;
my $npangrams_found = 0;
my %first_found;
for my $w (@found) {
    ++$first_found{uc substr($w, 0, 1)};
    $score += word_score($w);
    if ($is_pangram{$w}) {
        ++$npangrams_found;
    }
}

say "seven @seven";
say "pangrams: @pangrams";
say "npangrams: $npangrams, found: $npangrams_found";
say "bingo: $bingo";
say "max score: $max_score, score: $score";
say "nwords: $nwords, words found: $nfound";
say "words: @words";

my @color = qw/
    8E008E
    400098
    00C0C0
    008E00
    FFFF00
    FF8E00
    FF0000
    FF6599
    CD66FF
/;

my $width = 75 + 7*($nwords-1) + 18;
open my $out, '>', 'status.html';
print {$out} <<"EOH";
<html>
<head>
<style>
.lets, .bold_lets {
    font-size: 12pt;
    font-family: Arial;
}
.bold_lets {
    font-weight: bold;
    font-size: 13pt;
}
</style>
</head>
<body>
<svg width=$width height=300>
EOH
my $between = 18;
my $y = $between;
if ($bingo) {
    print {$out} "<text x=50 y=$y class=lets>B</text>\n";
    my $x = 75;
    for my $c (@seven) {
        my ($color, $class) = ('black', 'lets');
        if ($first_found{$c}) {
            ($color, $class) = ('green', 'bold_lets');
        }
        print {$out} "<text x=$x y=$y class=$class fill=$color>$c</text>\n";
        $x += 20;
    }
    $y += $between;
}

print {$out} "<text x=50 y=$y class=lets>P</text>\n";
my $x = 75;
$y -= 4;
for my $i (1 .. $npangrams_found) {
    print {$out} "<circle cx=$x cy=$y r=3 fill=green></circle>\n";
    $x += 7;
}
for my $i ($npangrams_found+1 .. $npangrams) {
    print {$out} "<circle cx=$x cy=$y r=2 fill=black></circle>\n";
    $x += 7;
}
$y += 4;
$y += $between;

print {$out} "<text x=48 y=$y class=lets>W</text>\n";
$x = 75;
$y -= 4;
for my $i (1 .. $nfound) {
    print {$out} "<circle cx=$x cy=$y r=3 fill=green></circle>\n";
    $x += 7;
}
for my $i ($nfound+1 .. $nwords) {
    print {$out} "<circle cx=$x cy=$y r=2 fill=black></circle>\n";
    $x += 7;
}
$y += 4;
$y += $between;

print {$out} "<text x=50 y=$y class=lets>S</text>\n";

# a black line from 0 to max_score
$y -=5; # centered on the S
my $max_x = 75 + ($nwords-1)*7;
my $x1 = 75;
print {$out} "<line x1=$x1 y1=$y x2=$max_x y2=$y stroke=black stroke-width=2></line>\n";

# colored ranks between the percentages
# but only up to the score %
my @pct = (0, 2, 5, 9, 15, 25, 40, 50, 70, 100);
my $score_pct = ($score/$max_score)*100;
PCT:
for my $i (0 .. $#pct-1) {
    my $x1 = 75 + ($pct[$i]/100)*($max_x - 75);
    if ($score_pct < $pct[$i+1]) {
        my $x2 = 75 + ($score_pct/100)*($max_x - 75);
        print {$out} "<line x1=$x1 y1=$y x2=$x2 y2=$y stroke='#$color[$i]' stroke-width=6></line>\n";
        last PCT;
    }
    my $x2 = 75 + ($pct[$i+1]/100)*($max_x - 75);
    print {$out} "<line x1=$x1 y1=$y x2=$x2 y2=$y stroke='#$color[$i]' stroke-width=6></line>\n";
}

# vertical marks between ranks
my $y1 = $y-5;
my $y2 = $y+5;
for my $pct (@pct) {
    my $x1 = 75 + ($pct/100)*($max_x - 75);
    my $x2 = $x1;
    print {$out} "<line x1=$x1 y1=$y1 x2=$x2 y2=$y2 stroke=black stroke-width=1></line>\n";
}

print {$out} <<'EOH';
</svg>
</body>
</html>
EOH

