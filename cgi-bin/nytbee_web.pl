#!/usr/bin/perl
use strict;
use warnings;

=comment

_will_ work on the phone but it's awkward.
so we won't try to have the 7 letters clickable/tappable

words in the order I saw them?
    and toggle back/forth
    the w command?
    sure, why not
    we do have the order

can we save the state of the puzzle
    by ip address?  maybe
        just ip+date => found, timestamp
    for when they return or refresh
    fun!
    and purge ones more than a week old
    save after every word found
        also whether they have hints/twolets
        and # hints?

dac on 12/23/21
    after getting acquaint and acquit
    still says AC:      why?

advantages: more than one word at a time, the hints and definitions
more entertaining and more colorful

return clears any message
    and also scrambles the letters
archive, random date

ny times logo image at top?
need help in new window - link at top
reserve blue for links
    not for not okay error messages

track IPs

commands:
    s <word> search for other puzzles with a word

track and tally nhints?

spacing issues - above hint table and two lets when no links are there
and space in front of two lets just once after choosing hint table.
should be able to fix this...

log?
1 2 - for random hints when not using the Hints Table or Two Letters
    yes

in hidden fields we store the minimum state we need:
    date, puzzle data from archive, found words
and we compute the rest - score, max_score, rankings, hint table
it is plenty fast

the usual web trick is to store the puzzle state
in a stateless environment... with hidden fields.

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
# date from new_words/command field (nr, n11 n12/23/18)
# date from hidden field (date)
# today
#
my $cmd = lc $params{new_words};
$cmd =~ s{\A \s* | \s* \z}{}xmsg;
my $first = date('5/29/18');
my $date;
my $today = my_today();
my $new_puzzle = 0;
if ($cmd =~ m{\A n \s* r \z}xms) {
    # random date since $first
    my $ndays = $today - $first + 1;
    $date = $first + int(rand $ndays);
    $date = $date->as_d8();
    $cmd = '';
    $params{found_words} = '';
    $new_puzzle = 1;
}
elsif ($cmd =~ m{\A n \s* (\d.*) \z}xms) {
    $date = date($1);
    if ($date) {
        # it is a valid date but is it in the range?
        if ($first <= $date && $date <= today()) {
            $date = $date->as_d8();
            $params{found_words} = '';
            $new_puzzle = 1;
            $cmd = '';
        }
        else {
            $date = '';
        }
    }
}
if (! $date) {
    $date = $params{date};      # hidden field
}
if (! $date) {
    # today
    $date = my_today()->as_d8();
    $new_puzzle = 1;
}
my $show_date = date($date)->format("%B %e, %Y");

# we have a valid date.
# get the puzzle data
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

sub word_score {
    my ($w) = @_;
    my $l = length $w;
    return ($l == 4? 1: $l) + ($is_pangram{$w}? 7: 0);
}
my $max_score = 0;
for my $w (@ok_words) {
    $max_score += word_score($w);
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

# now get the current data from the parameters
my @found = split ' ', $params{found_words};
my %is_found = map { $_ => 1 } @found;
my $in_order = 0;

my $ht_chosen = $new_puzzle? 0: $params{ht_chosen};
my $tl_chosen = $new_puzzle? 0: $params{tl_chosen};
my $nhints = $params{nhints};    # from before

my $score;
my $rank_name;
my $rank;

sub compute_score_and_rank {
    $score = 0;
    for my $w (@found) {
        $score += word_score($w);
    }
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
    # special case:
    if ($score >= $max_score) {
        $rank = 9;
        $rank_name = 'Queen Bee';
    }
}

# to be ready for the 'r' command
compute_score_and_rank();

# if no definition
# drop a final d or a final ed
# or ly?????
# and mark it as such
# the online dictionaries often give many different 
# definitions - let's just show 3 at the most.
# that's enough.  or maybe just 1?
# or all if Dcmd.
sub define {
    my ($word, $Dcmd, $dont_tally_hints, $dont_mask) = @_;

    my ($html, @defs);

    # merriam-webster
    $html = `curl -skL https://www.merriam-webster.com/dictionary/$word`;
    # to catch an adequate definition for 'bought':
    @defs = $html =~  m{meaning\s+of\s+$word\s+is\s+(.*?)[.]\s+How\s+to}xmsi;
    push @defs, $html =~ m{dtText(.*?)\n}xmsg;
    if ($Dcmd || ! @defs) {
        # some definitions (like 'from') use a different format
        # no clue why
        push @defs, ($html =~ m{"unText">(.*?)</span>}xmsg);
    }
    for my $def (@defs) {
        $def =~ s{\s+ \z}{}xms;     # trailing space
        $def =~ s{<[^>]*>}{}xmsg;   # strip tags
        $def =~ s{.*:\s+}{}xms;
    }
    if (! @defs) {
        # collins
        $html = `curl -skL https://www.lexico.com/en/definition/$word`;
        @defs = $html =~ m{Lexical\s+data\s+-\s+en-us">(.*?)</span>}xmsg;
    }
    my $stars = '*' x length $word;
    # sometimes the definition is duplicated so ...
    my %seen;
    my @tidied_defs;
    DEF:
    for my $d (@defs) {
        $d =~ s{<[^>]*>}{}xmsg; # excise any tags
        $d =~ s{[^[:print:]]}{}xmsg; # excise any non-printing chars
        $d =~ s{$word}{$stars}xmsgi unless $dont_mask;    # hide the word
        if ($seen{$d}++) {
            next DEF;
        }
        push @tidied_defs, $d;
    }
    if (! $Dcmd) {
        @tidied_defs = splice @tidied_defs, 0, 3;
    }
    if (@tidied_defs && ! $dont_tally_hints) {
        ++$nhints;
    }
    return join '',
           map {
               "<li>$_</li>\n";
           }
           @tidied_defs;
}

sub reveal {
    my ($word, $nlets, $beg_end) = @_;

    my $dash = ' &ndash;';
    my $lw = length $word;
    if ($nlets > $lw) {
        $nlets = $lw;
    }
    if (! $beg_end) {
        return uc(substr($word, 0, $nlets))
             . ($dash x ($lw-$nlets))
    }
    my $c2 = int($nlets/2);
    my $c1 = $nlets - $c2;
    my $cu = $lw - $nlets;
    ++$nhints;
    return uc(substr($word, 0, $c1))
           . ($dash x $cu)
           . uc(substr($word, $lw-$c2))
           ;
}

my $message = "";
# do we have a reveal command?
my $reveal = "";
if (my ($ev, $nlets, $term)
    = $cmd =~ m{
        \A ([ev])\s*(\d+)\s*(p|[a-z]\s*\d+|[a-z]\s*[a-z]) \z
      }xms
) {
    my $end = $ev eq 'e';
    if ($term eq 'p') {
        for my $p (grep { ! $is_found{$_} } @pangrams) {
            $message .= reveal($p, $nlets, $end) . "<br>\n";;
        }
    }
    elsif (my ($first, $len) = $term =~ m{\A ([a-z])\s*(\d+)}xms) {
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
        $term =~ s{\s}{}xmsg;
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
        $message = "\U$cmd\E:<ul>$message</ul><p>\n";
    }
    $cmd = '';
}
elsif ($cmd eq 'r') {
    $message = "<table cellpadding=5>\n";
    for my $r (0 .. 9) {
        $message .= "<tr>"
                 .  "<th>$ranks[$r]->{name}</th>"
                 .  "<td>$ranks[$r]->{value}</td>"
                 ;
        if ($rank == $r) {
            my $more = '';
            if ($rank != 9) {
                $more = ' '
                      . ($ranks[$r+1]->{value} - $score)
                      . ' more'
                      ;
            }
            $message .= "<td>*$more</td>";
        }
        $message .= "</tr>\n";
    }
    $message .= "</table>\n";
    $message = "<ul>$message</ul><p>";
    $cmd = '';
}
elsif (   $cmd =~ m{\A (d) \s*  (p|[a-z]\d|[a-z][a-z]) \z}xms
       || $cmd =~ m{\A (da) \s+ (p|[a-z]\d|[a-z][a-z]) \z}xms
) {
    my $Dcmd = $1 eq 'da';
    my $term = $2;
    my $line = "&mdash;" x 4;
    if ($term eq 'p') {
        for my $p (grep { !$is_found{$_} } @pangrams) {
            $message .= "<ul>"
                     .  define($p, $Dcmd, 0)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "Pangrams:$message<p>";
        }
        $cmd = '';
    }
    elsif ($term =~ m{([a-z])(\d)}xms) {
        my $let = $1;
        my $len = $2;
        $message = '';
        for my $w (
            grep {
                ! $is_found{$_}
                && length == $len
                && substr($_, 0, 1) eq $let
            }
            @ok_words
        ) {
            $message .= "<ul>"
                     .  define($w, $Dcmd, 0)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{<p>}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "\U$term\E:<br>$message<p>";
        }
        $cmd = '';
    }
    elsif ($term =~ m{([a-z][a-z])}xms) {
        my $lets = $1;
        $message = '';
        for my $w (
            grep {
                ! $is_found{$_}
                && substr($_, 0, 2) eq $lets
            }
            @ok_words
        ) {
            $message .= "<ul>"
                     .  define($w, $Dcmd, 0)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{<p>}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "\U$term\E:<br>$message<p>";
        }
        $cmd = '';
    }
}
elsif ($cmd =~ m{\A (d|da) \s+ ([a-z]+) \z}xms) {
    my $Dcmd = $1 eq 'da';
    my $word = $2;
    $message = "\U$word:"
             . "<ul>"
             . define($word, $Dcmd, 1, 1)
             . "</ul><p>"
             ;
    $cmd = '';
}
elsif ($cmd =~ m{\A g \s+ y \z}xms) {
    my @words = 
             map {
                 $is_pangram{lc $_}? length == 7? "<span class=purple>$_</span>"
                                    :             "<span class=green>$_</span>"
                :                    $_
             }
             map { ucfirst }
             @ok_words;
    $nhints += 100;
    $message = "<p class=mess>@words<p>";
    $cmd = '';
}
elsif ($cmd =~ m{\A c \s+ y \z}xms) {
    @found = ();
    %is_found = ();
    $nhints = 0;
    $ht_chosen = 0;
    $tl_chosen = 0;
    $cmd = '';
}
elsif ($cmd eq 'f') {
    # look for same 7
    my @dates;
    while (my ($dt, $puz) = each %puzzle) {
        if (substr($puz, 0, 7) eq $seven) {
            push @dates, $dt . uc substr($puz, 8, 1);
        }
    }
    $message = join '',
               map {
                  my ($dt, $y, $m, $d, $c) =  m{
                      \A (.. (..)(..)(..))(.) \z 
                  }xms;
                  "$m/$d/$y $c"
                  . ($dt eq $date? ' *': '')
                  . "<br>\n";
              }
              sort
              @dates
              ;
    $message = "$message<p>";
    $cmd = '';
}
elsif ($cmd =~ m{\A s \s+ ([a-z]+) \s* \z}xms) {
    # search the archive for the word
    # we're really searching everything after the |
    my $word = $1;
    my @dates;
    while (my ($dt, $puz) = each %puzzle) {
        if ($puz =~ m{\b$word\b}xms) {
            push @dates, $dt;
        }
    }
    $message = join '',
               map {
                   m{\A ..(..)(..)(..)}xms;
                   "$2/$3/$1<br>";
               }
               sort
               @dates
               ;
    if ($message) {
        $message = "\U$word\E:<br>$message<p>";
    }
    $cmd = '';
}
elsif ($cmd eq 'w') {
    $in_order = 1;
    $cmd = '';
}

# so we have dealt with the various commands.
# except for 1 and 2, that is.
# what new words might we have instead?
my @new_words;
if ($cmd !~ m{\A [12] \z}xms) {
    @new_words = map {
                     lc
                 }
                 split ' ', $cmd;
}
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

# now that we have added the new words...
compute_score_and_rank();

if ($not_okay_words) {
    $message = <<"EOH";
These words were not okay:
<p>
<ul>
$not_okay_words
</ul>
<p>
EOH
}

# ??? better way to handle ucfirst???
my $found_so_far
           = join ' ',
             map {
                 $is_pangram{lc $_}? length == 7? "<span class=purple>$_</span>"
                                 :             "<span class=green>$_</span>"
                : $is_new_word{lc $_}? "<span class=new_word>$_</span>"
                 : $_
             }
             map {
                ucfirst
             }
              $in_order? @found
             :           sort @found;

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

# now that #we have computed %sums and %two_lets
# perhaps $cmd was not words to add after all...
if ($cmd eq '1') {
    # find a random non-zero entry in the hint table
    my @entries;
    for my $l (4 .. $max_len) {
        for my $c (sort @seven) {
            if ($sums{$c}{$l}) {
                push @entries, "\U$c$l-$sums{$c}{$l}";
            }
        }
    }
    if (@entries) {
        # not Queen Bee yet
        ++$nhints;
        $message = $entries[ rand @entries ] . '<p>';
    }
}
elsif ($cmd eq '2') {
    # random non-zero entry in %two_lets
    my @entries;
    for my $k (sort keys %two_lets) {
        if ($two_lets{$k}) {
            push @entries, "\U$k-$two_lets{$k}";
        }
    }
    if (@entries) {
        # not Queen Bee yet
        ++$nhints;
        $message = $entries[ rand @entries ] . '<p>';
    }
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

# generate the rank colors and font sizes
my $rank_colors_fonts = "";
for my $i (0 .. 9) {
    my $color = 205-10*$i;
    my $size = 15+3*$i;
    $rank_colors_fonts .= <<"EOCSS";
.rank$i {
    font-size: ${size}pt;
    color: rgb(255, $color, 255);
}
EOCSS
}

my $image = '';
my $log = 'http://logicalpoetry.com';
if (7 <= $rank && $rank <= 9) {
    my $name = lc $ranks[$rank]->{name};
    $name =~ s{\s.*}{}xms;  # for queen bee
    $image = "<img class=image src=$log/pics/$name.jpg>";
}

my $disp_nhints = "";
if ($nhints) {
    $disp_nhints = "<br>Hints: "
                 . ($nhints
                    + ($ht_chosen? 10: 0)
                    + ($tl_chosen?  5: 0));
}

my $ht_disp = $ht_chosen? "block": "none";
my $tl_disp = $tl_chosen? "block": "none";
my $links = "";
if (!$ht_chosen) {
    $links .= "<a href=# id=ht_link onclick='hint_table();'>Hint Table</a>";
}
if (!$tl_chosen) {
    if ($links) {
        $links .= "&nbsp;" x 4;
    }
    $links .= "<a href=# id=tl_link onclick='two_lets()'>Two Letters</a>";
}

# now to display everything

print <<"EOH";
<html>
<head>
<style>
.help {
    margin-left: .7in;
}
.mess {
    width: 600px;
    word-spacing: 10px;
}
a {
    text-decoration: none;
    color: blue;
}
.float-child {
    float: left;
}
.hint_table {
    display: $ht_disp;
}
.two_lets {
    display: $tl_disp; 
    margin-left: 10mm;
}
.new_word {
    color: coral;
}
ul {
    margin-top: 0px;
    margin-bottom: 0px;
}
li {
    width: 600px;
}
td, th {
    text-align: right;
    font-size: 17pt;
    font-family: Arial;
}
.not_okay {
    color: red;
}
pre {
    font-size: 24pt;
}
body {
    margin-top: .3in;
    margin-left: .3in;
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
    width: 600px;
    word-spacing: 10px;
}
.submit {
    background: green;
    color: white;
}
.rank_name {
    margin-left: .5in;
}
$rank_colors_fonts
.rank9 {
    font-weight: bold;
}
.image {
    width: 150px;
}
</style>
<script>
function hint_table() {
    document.getElementById('hint_table').style.display = 'block';
    document.getElementById('ht_link').style.display = 'none';
    document.getElementById('ht_chosen').value = '1';
    document.form.new_words.focus();
}
function two_lets() {
    document.getElementById('two_lets').style.display = 'block';
    document.getElementById('tl_link').style.display = 'none';
    document.getElementById('tl_chosen').value = '1';
    document.form.new_words.focus();
}
</script>
</head>
<body>
NY Times Spelling Bee Puzzle<span class=help><a target=_blank href='http://logicalpoetry.com/nytbee'>Help</a><br>$show_date
<p>
<form id=main name=form method=POST>
<input type=hidden name=date value='$date'>
<input type=hidden name=puzzle value='$puzzle'>
<input type=hidden name=found_words value='@found'>
<input type=hidden name=nhints value=$nhints>
<input type=hidden name=ht_chosen id=ht_chosen value=$ht_chosen>
<input type=hidden name=tl_chosen id=tl_chosen value=$tl_chosen>
<pre>
     $six[0]   $six[1]
   $six[2]   <span class=red2>\U$center\E</span>   $six[3]
     $six[4]   $six[5]
</pre>
$message
<input class=new_words type=text size=30 name=new_words><br>
</form>
<div class=found_so_far>
$found_so_far
</div>
<p>
Score: $score<span class='rank_name rank$rank'>$rank_name</span>
$image
$disp_nhints
<p>
$links
<div class=float-container>
    <div class=float-child>
        <div id=hint_table class=hint_table>
Words: $nwords, Points: $max_score<br>Pangrams: $npangrams$perfect$bingo
<p>
        $hint_table
        </div>
    </div>
    <div class=float-child>
        <div id=two_lets class=two_lets>
        $two_lets
        </div>
    </div>
</div>
</body>
<script>document.form.new_words.focus();</script>
</html>
EOH
