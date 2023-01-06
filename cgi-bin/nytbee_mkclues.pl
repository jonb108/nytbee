#!/usr/bin/perl
use strict;
use warnings;

# a poor man's database
use DB_File;
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';

use BeeUtil qw/
    cgi_header
    table
    Tr
    td
    $log
    my_today
    ymd
/;
use Date::Simple qw/
    date
/;
use Bee_DBH qw/
    $dbh
    get_person
    get_clues
/;
use CGI;
use CGI::Carp qw/
    fatalsToBrowser
    warningsToBrowser
/;

my $q = CGI->new();
my $uuid = cgi_header($q);

my $cgi = "$log/cgi-bin";
my $date;
my $all_words = $q->path_info() eq '/today';;
#
# the directory logicalpoetry.com/mkclues has an index.html
# file that redirects to logicalpoetry.com/cgi-bin/nytbee_mkclues.pl/today

if ($all_words) {
    $date = my_today()->as_d8();
}
else {
    $date = $q->param('date');
}
open my $out, '>>', 'beelog/' . ymd();
print {$out} substr($uuid, 0, 11) . " mkclues $date\n";
close $out;

my $puzzle = $puzzle{$date};
$puzzle =~ s{\A [^|]* [|]\ s* }{}xms;
my @words = $puzzle =~ m{([a-z]+)}xmsg;
my $show_date = date($date)->format("%B %e, %Y");

my @found;
if ($all_words) {
    @found = @words;
}
else {
    @found = grep { ! m{ [+*-]\z }xms }
             split ' ', $q->param('found');
}

my $nnf = @words - @found;
my $nnf_disp = '';
if ($nnf) {
    if ($nnf == 1) {
        $nnf_disp = "As you know, there is 1 word that has not yet been found.  This word will be hidden.<p>";
    }
    else {
        $nnf_disp = "As you know, there are $nnf words that have not yet been found.  These words will be hidden.<p>";
    }
}

my ($person_id, $name, $location) = get_person($uuid);

my %clue_for;
my $got_clues = 0;

if ($person_id) {
    # we've seen this person before
    # they have either made a puzzle or added clues
    # for some date (maybe not the current one).
    #
    # first, see if there are EXISTING clues for this date
    # from this person
    #
    my $sth_clue = $dbh->prepare(<<'EOS');

        SELECT word, clue
          FROM bee_clue
         WHERE person_id = ?
           AND date = ?

EOS
    $sth_clue->execute($person_id, $date);
    while (my ($word, $clue) = $sth_clue->fetchrow_array()) {
        $clue_for{$word} = $clue;
        $got_clues = 1;
    }
}
if ($got_clues) {
    push @found, keys %clue_for;
    # and de-dup them
    my %seen;
    @found = grep { !$seen{$_}++ } @found;
}

my %is_found = map { $_ => 1 } @found;

my ($href_prior_clues_for, $json)
    = get_clues($person_id, \@found, \%clue_for);

my $prior_clues = %$href_prior_clues_for?
    "<p>You have given clues for some of the words before.": '';
if ($json ne '{}') {
    $prior_clues .= " If there is more than one clue for a word you can cycle through them by clicking the <img height=25 src=$log/nytbee/pics/cycle.jpg> icon.";
}

print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
<script src="$log/nytbee/js/nytbee.js"></script>
<script>
var clues_for = $json;
function cycle(w) {
    clues_for[w].cur = (clues_for[w].cur + 1) % clues_for[w].clues.length;
    document.getElementById(w + '_clue').value
        = clues_for[w].clues[ clues_for[w].cur ];
}
</script>
</head>
<body>
<h2>Clues for the NYT Puzzle<a target=nytbee_help class=help href='$log/nytbee/help.html#clues'>Help</a><br>on $show_date</h2>
<form name=form action='$cgi/nytbee_mkclues2.pl' onsubmit="return check_name_location();" method=POST>
<input type=hidden name=date value='$date'>
<input type=hidden name=all_words value='$all_words'>
<p>
$nnf_disp
You do not have to give clues for all of the words.  You can return
here to update and revise your clues.
<p>
Clicking on the words will show a brief dictionary definition.
SHIFT-clicking on the words will give a <i>complete</i> dictionary definition.
You may, instead, wish to give clues that are more
ambiguous, clever, wordplay &#128522; - like clues for a crossword puzzle.
$prior_clues
<p>
<table cellpadding=3>
<tr><td>Your Name</td><td class=lt><input name=name id=name size=30 value='$name'></td></tr>
<tr><td>Your Location</td><td class=lt><input name=location id=location size=30 value='$location'></td></tr>
<tr><td colspan=2>&nbsp;</td></tr>
EOH
for my $w (@words) {
    my $uw = ucfirst $w;
    my ($word_td, $clue_td, $cycle_td);
    if ($is_found{$w}) {
        my $clue;
        if (exists $href_prior_clues_for->{$w}) {
            if (ref $href_prior_clues_for->{$w}) {
                # there is more than one prior clue
                $clue = $href_prior_clues_for->{$w}->[0];
                $cycle_td = td(qq!<img class=cursor onclick='cycle("$w");' src='/nytbee/pics/cycle.jpg'>!);
            }
            else {
                $clue = $href_prior_clues_for->{$w};
            }
        }
        else {
            $clue = '';
        }
        $word_td = td(qq!<span class=cursor onclick="popup_define('$w',200,500)">$uw</span>!);
        $clue_td = td("<input type=text size=40 name=${w}_clue id=${w}_clue"
                 . qq! value="$clue">!)
    }
    else {
        $word_td = td({ class => 'word_td'}, '&nbsp;');
        $clue_td = td('&nbsp;');
    }
    print Tr($word_td, $clue_td, $cycle_td), "\n";
}
print Tr(td('&nbsp'), td({ class => 'lt' }, "<button type=submit>Submit</button>")), "\n";
print <<"EOH";
</table>
</body>
</html>
<script>document.form.name.focus()</script>
EOH
