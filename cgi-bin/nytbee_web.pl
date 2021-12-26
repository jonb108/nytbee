#!/usr/bin/perl
use strict;
use warnings;

=comment

is it POST or GET?
    hitting Return gives long url
need new web page for nytbee_cmd.pl
ny times logo image at top
need popup help window
.rankX - increasing size and redness pink to magenta?
emoticons for some of the ranks?
images for genius and queen bee?
advantage: more than one word at a time, the hints and definitions
    the archive, random
keep track of assists? or not?
more entertaining and more colorful
random date
dictionary definitions - from nytbee command line
    d e4
    d de
    d p
    d word

    # in separate window?
    # or at bottom
    S word  
    f       
track IP addresses

in hidden fields we store the minimum state we need:
    date, puzzle data from archive, found words
and we compute the rest - score, max_score, rankings, hint table
it is plenty fast

=cut

use CGI;
my $q = CGI->new();
print $q->header();
my %params = $q->Vars();

use DB_File;
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';

use Date::Simple qw/
    today
    date
/;

sub my_today {
    my ($hour) = (localtime)[2];
    my $today = today();
    if ($hour < 3) {
        --$today;
    }
    return $today;
}

# puzzle from which date?
# date from form (dt), date from hidden field (date), or today
#
my $date = $params{dt};
my $today = my_today();
# blank = today
# r     = random between 5/29/18 and today
# 3     = 3rd of the current month
# 10/3  = Oct 3 of current year
# 9/3/18 = that date
# 08/14/2021 = that date
#
if ($date) {
    my $first = date('5/29/18');
    if ($date =~ m{\A \s* r}xmsi) {
        my $ndays = $today - $first + 1;
        $date = $first + int(rand $ndays);
        $date = $date->as_d8();
    }
    else {
        $date = date($date);
        if ($date) {
            # it is a valid date but ...
            if ($first <= $date && $date <= today()) {
                $date = $date->as_d8();
            }
            else {
                $date = '';
            }
        }
    }
}
if (! $date) {
    $date = $params{date};      # hidden field
}
if (! $date) {
    $date = my_today()->as_d8();
}
my $show_date = date($date)->format("%B %e, %Y");

my $puzzle = $puzzle{$date};
my ($s, $t) = split /[|]/, $puzzle;
my ($seven, $center, @pangrams) = split ' ', $s;
my @seven = split //, $seven;
my (@ok_words) = split ' ', $t;
my $nwords = @ok_words;
my $npangrams = @pangrams;

my %is_pangram = map { $_ => 1 } @pangrams;
my %is_ok_word = map { $_ => 1 } @ok_words;
my @six = map { uc }
          grep { $_ ne $center }
          @seven;

# scramble
my @new;
push @new, splice @six, rand @six, 1 while @six;
@six = @new;

my @found = split ' ', $params{found_words};
my %is_found = map { $_ => 1 } @found;

sub reveal {
    my ($word, $nlets, $beg_end) = @_;
    my $lw = length $word;
    if ($nlets > $lw) {
        $nlets = $lw;
    }
    if (! $beg_end) {
        return uc substr($word, 0, $nlets)
             . ('-' x ($lw-$nlets))
    }
    my $c2 = int($nlets/2);
    my $c1 = $nlets - $c2;
    my $cu = $lw - $nlets;
    return uc substr($word, 0, $c1)
           . ('-' x $cu)
           . uc substr($word, $lw-$c2)
           ;
}

my $message = "";
# do we have a reveal command?
my $reveal = "";
my $cmd = lc $params{new_words};
$cmd =~ s{\s}{}xmsg;
if (my ($ev, $nlets, $term)
    = $cmd =~ m{
        \A ([ev])(\d+)(p|[a-z]\d+|[a-z][a-z]) \z
      }xms
) {
    my $end = $ev eq 'e';
    if ($term eq 'p') {
        for my $p (grep { ! $is_found{$_} } @pangrams) {
            $message .= reveal($p, $nlets, $end) . "<br>\n";;
        }
    }
    elsif (my ($first, $len) = $term =~ m{\A ([a-z])(\d+)}xms) {
        for my $w (
            grep {
                ! $is_found{$_}
                && substr($_, 0, 1) eq $first
                && length == $len
            }
            @ok_words
        ) {
            $message .= reveal($w, $nlets, $end) . "<br>\n";;
        }
    }
    else {
        # $term is two letters
        for my $w (
            grep {
                ! $is_found{$_}
                && substr($_, 0, 2) eq $term
            }
            @ok_words
        ) {
            $message .= reveal($w, $nlets, $end) . "<br>\n";;
        }
    }
    if ($message) {
        $message = "The hint \U$params{new_words}\E yields:<ul>$message</ul>\n";
    }
    $params{new_words} = '';
}
# now what new words do we have?
my @new_words = map {
                    lc
                }
                split ' ', $params{new_words};
sub check_word {
    my ($w) = @_;
    if (length $w < 4) {
        return 'too short';
    }
    if (index($w, $center) < 0) {
        return "does not contain: <span class=red1>\U$center</span>";
    }
    for my $c (split //, $w) {
        if (index($seven, $c) < 0) {
            return "\U$c\E is not in \U$seven";
        }
    }
    if (! exists $is_ok_word{lc $w}) {
        return "not in word list";
    }
    return '';
}
my $not_okay_words;
my %is_new_word;
for my $w (@new_words) {
    if (my $mess = check_word($w)) {
        $not_okay_words .= "<span class=not_okay>" 
                        .  uc($w)
                        .  "</span>: $mess<br>";
    }
    elsif (! $is_found{$w}) {
        push @found, $w;
        $is_found{$w} = 1;
        $is_new_word{$w} = 1;
    }
}
if ($not_okay_words) {
    $message = <<"EOH";
These words were not okay:
<ul>
$not_okay_words
</ul>
EOH
}

# ??? better way to handle ucfirst???
my $found_so_far
           = join ' ',
             map {
                 $is_pangram{lc $_}? length == 7? "<span class=purple>$_</span>"
                                 :             "<span class=green>$_</span>"
                : $is_new_word{lc $_}? "<span class=red1>$_</span>"
                 : $_
             }
             map {
                ucfirst
             }
             sort
             @found;

# now compute score and max score
#
sub word_score {
    my ($w) = @_;
    my $l = length $w;
    return ($l == 4? 1: $l) + ($is_pangram{$w}? 7: 0);
}
my ($max_score, $score) = (0, 0);
for my $w (@ok_words) {
    $max_score += word_score($w);
}
for my $w (@found) {
    $score += word_score($w);
}
my @ranks = (
    { name => 'Beginner',   value => 0 },
    { name => 'Good Start', value => int(.02*$max_score + 0.5) },
    { name => 'Moving Up',  value => int(.05*$max_score + 0.5) },
    { name => 'Good',       value => int(.08*$max_score + 0.5) },
    { name => 'Solid',      value => int(.15*$max_score + 0.5) },
    { name => 'Nice',       value => int(.25*$max_score + 0.5) },
    { name => 'Great',      value => int(.40*$max_score + 0.5) },
    { name => 'Amazing',    value => int(.50*$max_score + 0.5) },
    { name => 'Genius',     value => int(.70*$max_score + 0.5) },
    { name => 'Queen Bee',  value => $max_score },
);
my $rank_name;
my $rank;
RANK:
for my $r (0 .. $#ranks-1) {
    # note that $#ranks is Queen Bee == 9
    if (   $score >= $ranks[$r]->{value}
        && $score <  $ranks[$r+1]->{value}
    ) {
        $rank_name = $ranks[$r]->{name};
        $rank = $r;
        last RANK;
    }
}
if ($score == $max_score) {
    $rank = 9;
    $rank_name = 'Queen Bee';
}
# for fun - color too?? yeah.
my @font_size = qw/
    12 14 16 20 
    24 28 32 36
    40 48
/;

my %sums;
my %two_lets;
my $max_len = 0;
WORD:
for my $w (@ok_words) {
    my $l = length($w);
    if ($max_len < $l) {
        $max_len = $l;
    }
    if ($is_found{$w}) {
        # skip it
        next WORD;
    }
    my $c1 = substr($w, 0, 1);
    my $c2 = substr($w, 0, 2);
    ++$sums{$c1}{$l};
    ++$two_lets{$c2};
}
my $bingo = ", Bingo";
CHAR:
for my $c (@seven) {
    if (! exists $sums{$c}) {
        $bingo = '';
        last CHAR;
    }
}
my $perfect = '';
my $nperfect = 0;
for my $p (keys %is_pangram) {
    if (length $p == 7) {
        ++$nperfect;
    }
}
if ($nperfect) {
    $perfect = " ($nperfect Perfect)"
}

# the hint table
my $hint_table = "<table cellpadding=2 border=0>\n";
my $space = '&nbsp;' x 4;
$hint_table .= "<tr><th>&nbsp;</th>";
for my $l (4 .. $max_len) {
    $hint_table .= "<th>$space$l</th>";
}
$hint_table .= "<th>$space&nbsp;&Sigma;</th></tr>\n";
my $tot = 0;
for my $c (@seven) {
    $hint_table .= "<tr><th style='text-align: center'>\U$c\E</th>";
    my $sum = 0;
    for my $l (4 .. $max_len) {
        $hint_table .= "<td>" .  ($sums{$c}{$l} || '-') . "</td>";
        $sum += $sums{$c}{$l};
    }
    $hint_table .= "<th>$sum</th></tr>\n";
    $tot += $sum;
}
$hint_table .= "<tr><th style='text-align: right'>&Sigma;</th>";
for my $l (4 .. $max_len) {
    my $sum = 0;
    for my $c (@seven) {
        $sum += $sums{$c}{$l};
    }
    $hint_table .= "<th>$sum</th>";
}
$hint_table .= "<th>$tot</th></tr>\n";
$hint_table .= "</table>\n";

# two letter tallies
my $two_lets = '';
my @two = grep {
              $two_lets{$_}
          }
          sort
          keys %two_lets;
TWO:
for my $i (0 .. $#two) {
    if ($two_lets{$two[$i]} == 0) {
        next TWO;
    }
    $two_lets .= "\U$two[$i]-$two_lets{$two[$i]}";
    if ($i < $#two
        && substr($two[$i], 0, 1) ne substr($two[$i+1], 0, 1)
    ) {
        $two_lets .= "<p>";
    }
    else {
        $two_lets .= '&nbsp;&nbsp;';
    }
}

# now to display everything

print <<"EOH";
<html>
<head>
<style>
.two_lets {
    text-align: left;
    text-indent: .4in;
}
td, th {
    text-align: right;
    font-size: 17pt;
    font-family: Arial;
}
.not_okay {
    color: blue;
}
pre {
    font-size: 24pt;
}
body {
    margin-top: .5in;
    margin-left: .5in;
    font-size: 18pt;
    font-family: Arial;
}
input, .submit {
    font-size: 18pt;
    font-family: Arial;
}
.new_words {
    text-transform: uppercase;
}
.over {
    margin-left: 1in;
}
.red1, .red2 {
    color: red;
}
.red2 {
    font-weight: bold;
}
.green {
    color: green;
}
.purple {
    color: purple;
}
.found_so_far {
    margin-left: .5in;
    width: 600px;
    word-spacing: 10px;
}
.submit {
    background: green;
    color: white;
}
.rank_name {
    margin-left: 1in;
}
.rank0 {
    font-size: 20pt;
    color: pink;
}
.rank1 {
    font-size: 25pt;
    color: red;
}
.rank9 {
    font-size: 38pt;
    color: magenta;
    font-weight: bold;
}
</style>
</head>
<body>
<form>NY Times Spelling Bee<br>
Puzzle for $show_date <span class=over>Date: <input type=text size=10 name=dt></span></form>
<p>
<form id=main name=form>
<input type=hidden name=date value='$date'>
<input type=hidden name=puzzle value='$puzzle'>
<input type=hidden name=found_words value='@found'>
<pre>
     $six[0]   $six[1]
   $six[2]   <span class=red2>\U$center\E</span>   $six[3]
     $six[4]   $six[5]
</pre>
$message
New words: <input class=new_words type=text size=40 name=new_words><br>
</form>
Words you have found:<br>
<div class=found_so_far>
$found_so_far
</div>
<p>
Score: $score<span class='rank_name rank$rank'>$rank_name</span>
<p>
Words: $nwords, Points: $max_score, Pangrams: $npangrams$perfect$bingo
<p>
<table cellpadding=20 border=0>
<tr><td>
$hint_table
</td><td class=two_lets>
$two_lets
</td></tr>
</table>
<!-- <form><button type=submit formaction='http://logicalpoetry.com' formtarget=_blank>home</button></form> -->
</body>
<script>document.form.new_words.focus();</script>
</html>
EOH
