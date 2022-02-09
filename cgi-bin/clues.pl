#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use CGI::Carp qw/
    warningsToBrowser
    fatalsToBrowser
/;
use BeeUtil qw/
    cgi_header
    uniq_chars
    error
    table
    Tr
    td
    $log
/;
use Bee_DBH qw/
    $dbh
    get_person
    get_clues
/;

my $q = CGI->new();
my $uuid = cgi_header($q);

my ($person_id, $name, $location) = get_person($uuid);
# note that $person_id may be undef
# we create the bee_person record only when ...

my $seven = $q->param('seven');
my $center = $q->param('center');
my @other_words = split ' ', lc $q->param('other_words');
my $regex = qr{[^$seven]}xms;

# do these extra words 'qualify'?
my @not_okay;
for my $w (@other_words) {
    if (length $w < 4
        || $w =~ $regex
        || index($w, $center) < 0
    ) {
        push @not_okay, $w;
    }
}
if (@not_okay) {
    error "These words do not qualify:<ul>"
        . join('', map { "$_<br>\n" } @not_okay)
        . "</ul>\n";
}
my @ok_words = sort $q->param('ok'), @other_words;
# is there at least one pangram?
my @pangrams;
for my $w (@ok_words) {
    if (uniq_chars($w) == 7) {
        push @pangrams, $w;
    }
}
if (! @pangrams) {
    error "In the many words there is no pangram! :(";
}

# did the person give a clue for any of the @ok_words before?
# offer them..
# there may be more than one - in this case have a way
# to cycle through the clues - (in date order?).
# with community puzzles coming first.
# dup code with nytbee_clues???
# can we reuse?
#
my ($href_prior_clues_for, $json) = get_clues($person_id, \@ok_words);
my $prior_clues = %$href_prior_clues_for?
    "<p>You have given clues for some of the words before.": '';
my $cycle_function = '';
if ($json ne '{}') {
    $prior_clues .= " If there is more than one clue for a word you can cycle through them by clicking the <img height=25 src=/nytbee/pics/cycle.jpg> icon.<p>";
    $cycle_function = <<"EOJ";
var clues_for = $json;
function cycle(w) {
    clues_for[w].cur = (clues_for[w].cur + 1) % clues_for[w].clues.length;
    document.getElementById(w + '_clue').value
        = clues_for[w].clues[ clues_for[w].cur ];
}
EOJ
}

print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
<script>
var newwin;
function popup_define(word, height, width) {
    document.getElementById(word + '_clue').focus();
    newwin = window.open(
        '$log/cgi-bin/nytbee_define.pl/' + word, 'define',
        'height=' + height + ',width=' + width +', scrollbars'
    );
    newwin.moveTo(800, 0);
}
$cycle_function
</script>
</head>
<body>
<h1>Making an NYT Type<br>Spelling Bee Puzzle<br>Step <span class=red>4</span> <span class=step_name>Clues</span></h1>
Optionally, provide clues for each word.
$prior_clues
You can click on the words to get a dictionary definition.
You may, instead, wish to give clues that are ambiguous, clever, wordplay &#128522; - like clues for a crossword.
<p>
<form name=form action=$log/cgi-bin/get_clues.pl method=POST>
<input type=hidden name=seven value='$seven'>
<input type=hidden name=center value='$center'>
<input type=hidden name=words value='@ok_words'>
<input type=hidden name=pangrams value='@pangrams'>
EOH
my @rows;
for my $w (@ok_words) {
    my $uw = ucfirst $w;
    my ($word_td, $clue_td, $cycle_td);
    my $clue;
    if (exists $href_prior_clues_for->{$w}) {
        if (ref $href_prior_clues_for->{$w} eq 'ARRAY') {
            # there is more than one prior clue
            $clue = $href_prior_clues_for->{$w}->[0];
            $cycle_td = td(qq!<img class=cursor onclick='cycle("$w");' src='/nytbee/cycle.jpg'>!);
        }
        else {
            $clue = $href_prior_clues_for->{$w};
        }
    }
    else {
        $clue = '';
    }
    $word_td = td(qq!<a href="javascript:popup_define('$w',300,500)">$uw</a>!);
    $clue_td = td("<input type=text size=40 name=${w}_clue id=${w}_clue"
             . qq! value="$clue">!);
    push @rows, Tr($word_td, $clue_td, $cycle_td);
}
push @rows, Tr(td(''), td({ class => 'lt' }, '<button type=submit>Submit</button>'));
print table(@rows);
print <<"EOH";
</body>
</html>
<script>document.form.$ok_words[0]_clue.focus();</script>
EOH

=comment

The usual NYT Spelling Bee puzzle includes
ALL normal qualifying words.   If there are clues for
each word then the maker of the puzzle need not include ALL.
Instead, it becomes a kind of crossword puzzle with clues where
you know that the answer words are composed of the seven letters.
You're not trying to 'find' all words that can be made.

=cut