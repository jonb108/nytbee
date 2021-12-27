#!/usr/bin/perl
use strict;
use warnings;

=comment

advantages: more than one word at a time, the hints and definitions
more entertaining and more colorful
archive, random date

ny times logo image at top?
need help in new window - link at top
reserve blue for links
    not for not okay error messages

track IPs

commands:
    c clear and restart after js confirmation
    g for give up - show all words after js confirmation
    s <word> search for other puzzles with this word
    f search for other puzzles with this 7
    # in separate window?

track assists?
don't always have the hints table and two letter list?
    onclick of buttons (or links) change display of divs from none to block?
    hints/two let separate?
    and remember the settings in hidden fields
    the hints table includes the 
        "Words: 54, Points: 259, Pangrams: 1, Bingo"
    line
    use just divs - look up side-by-side again
        tables sort of suck for this purpose

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
# date from new_words/command field (nr, n11 n12/23/18)
# date from hidden field (date)
# today
#
my $cmd = lc $params{new_words};
$cmd =~ s{\A \s* | \s* \z}{}xmsg;
my $first = date('5/29/18');
my $date;
my $today = my_today();
if ($cmd eq 'nr') {
    # random date since $first
    my $ndays = $today - $first + 1;
    $date = $first + int(rand $ndays);
    $date = $date->as_d8();
    $params{new_words} = '';
    $params{found_words} = '';
}
elsif ($cmd =~ m{\A n \s* (\d.*) \z}xms) {
    $date = date($1);
    if ($date) {
        # it is a valid date but is it in the range?
        if ($first <= $date && $date <= today()) {
            $date = $date->as_d8();
            $params{new_words} = '';
            $params{found_words} = '';
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

my @found = split ' ', $params{found_words};
my %is_found = map { $_ => 1 } @found;

my $ht_chosen = $params{ht_chosen};
my $tl_chosen = $params{tl_chosen};
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
    my ($word, $Dcmd, $dont_tally_assists, $dont_mask) = @_;

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
        $message = "The hint \U$cmd\E yields:<ul>$message</ul><p>\n";
    }
    $params{new_words} = '';
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
    $params{new_words} = '';
}
elsif ($cmd =~ m{\A (d|da) \s+ (p|[a-z]\d|[a-z][a-z]) \z}xms) {
    my $Dcmd = $1 eq 'da';
    my $term = $2;
    my $line = "&mdash;" x 4;
    if ($term eq 'p') {
        $message = 'pangrams:';
        for my $p (grep { !$is_found{$_} } @pangrams) {
            $message .= "<ul>"
                     .  define($p, $Dcmd, 1)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{<p>}xms;
        $message =~ s{--}{$line<br>}xmsg;
        $params{new_words} = '';
    }
    elsif ($term =~ m{([a-z])(\d)}xms) {
        my $let = $1;
        my $len = $2;
        $message = "\U$term:<br>";
        for my $w (
            grep {
                ! $is_found{$_}
                && length == $len
                && substr($_, 0, 1) eq $let
            }
            @ok_words
        ) {
            $message .= "<ul>"
                     .  define($w, $Dcmd, 1)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{<p>}xms;
        $message =~ s{--}{$line<br>}xmsg;
        $params{new_words} = '';
    }
    elsif ($term =~ m{([a-z][a-z])}xms) {
        my $lets = $1;
        $message = "\U$term:<br>";
        for my $w (
            grep {
                ! $is_found{$_}
                && substr($_, 0, 2) eq $lets
            }
            @ok_words
        ) {
            $message .= "<ul>"
                     .  define($w, $Dcmd, 1)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{<p>}xms;
        $message =~ s{--}{$line<br>}xmsg;
        $params{new_words} = '';
    }
}
elsif ($cmd =~ m{\A (d|da) \s+ ([a-z]+) \z}xms) {
    my $Dcmd = $1 eq 'da';
    my $word = $2;
    $message = ucfirst($word)
             . ":"
             . "<ul>"
             . define($word, $Dcmd, 1, 1)
             . "</ul><p>"
             ;
    $params{new_words} = '';
}

# so we have dealt with the various commands.
# what new words might we have instead?
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

# now that we have added the new words to @found
# we can recompute score and rank
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
             sort
             @found;

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

# now to display everything

print <<"EOH";
<html>
<head>
<style>
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
    color: brown;
}
ul {
    margin-top: 0px;
    margin-bottom: 0px;
}
li {
    width: 700px;
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
    margin-left: .5in;
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
NY Times Spelling Bee Puzzle<br>$show_date
<p>
<form id=main name=form method=POST>
<input type=hidden name=date value='$date'>
<input type=hidden name=puzzle value='$puzzle'>
<input type=hidden name=found_words value='@found'>
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
<p>
Words: $nwords, Points: $max_score, Pangrams: $npangrams$perfect$bingo
<p>
$links
<div class=float-container>
    <div class=float-child>
        <div id=hint_table class=hint_table>
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
