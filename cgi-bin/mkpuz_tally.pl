#!/usr/bin/perl
# if no pangrams at all - give error
# note about dictionary definitions - so no need for all clues
# clues are more subtle - like a crossword clue
# in clue form - have link for dict definition
# look for 'command line' in the help
# will there be issues with too many users?
#       fast-cgi, mod_perl
#       a dedicated server and domain
# Q for an inspiring quote
#       vegan and progressive centric
use strict;
use warnings;
use CGI;
my $q = CGI->new();
my $uuid = cgi_header($q);
# 9060f4f4-b124-11ee-b0d4-ac0cb0d5d1d5
my @f = split '-', $uuid;
if (@f == 5) {
    print <<'EOH';
<style>
body {
font-size: 18pt;
margin: .5in;
}
</style>
Sorry, you must set your own ID (with the ID command) in the puzzle before you can create a puzzle!
EOH
    exit;
}

use BeeUtil qw/
    uniq_chars
    error
    word_score
    trim
    $log
    cgi_header
    ymd
    JON
/;

print <<"EOH";
<html>
<head>
<title>
UltraBee - Creating a Community Puzzle - Center Letter
</title>
<link rel='stylesheet' type='text/css' href='$log/css/cgi_style.css'/>
</head>
<body>
EOH


my $word = lc trim $q->param('word');
my $Word = ucfirst trim $q->param('word');
if (length $word == 0) {
    error "Missing pangramic word";
}

open my $out, '>>', 'beelog/' . ymd();
print {$out} substr($uuid, 0, 11) . " making a puzzle with '$Word'\n";
close $out;

my @lets = uniq_chars($word);
if (@lets != 7) {
    error "There are not 7 unique letters in '$word'.";
}
my $lets = join '', @lets;
my $regex = qr{[^$lets]}xms;
my (%tot, %btot);
my (%score, %bscore);
my (%four, %bfour);
my (@pangrams, @bpangrams);

open my $in, '<', 'nyt-words.txt';
while (my $word = <$in>) {
    chomp $word;
    if ($word !~ $regex) {
        my @uchars = uniq_chars($word);
        my $pangram = @uchars == 7;
        if ($pangram) {
            push @pangrams, $word;
        }
        for my $c (@uchars) {
            ++$tot{$c};
            if (length $word == 4) {
                ++$four{$c};
            }
            $score{$c} += word_score($word, $pangram);
        }
    }
}
close $in;
my $npangrams = @pangrams;
my $pl = $npangrams == 1? '': 's';

# Now for the Big lexicon
#
open my $in2, '<', 'other-words.txt';
while (my $bword = <$in2>) {
    chomp $bword;
    if ($bword !~ $regex) {
        my @uchars = uniq_chars($bword);
        my $pangram = @uchars == 7;
        if ($pangram) {
            push @bpangrams, $bword;
        }
        for my $c (@uchars) {
            ++$btot{$c};
            if (length $bword == 4) {
                ++$bfour{$c};
            }
            $bscore{$c} += word_score($bword, $pangram);
        }
    }
}
close $in2;
my $bnpangrams = @bpangrams;
my $bpl = $bnpangrams == 1? '': 's';

my $msg = '';
if ($npangrams + $bnpangrams == 0) {
    $msg = "No pangrams at all!  We'll put " . ucfirst($word) . ' in "Other qualified" words.<p>';
}

print <<"EOH";
<h1>Creating a<br>Community Puzzle<br>Step <span class=red>2</span> <span class=step_name>Center Letter</span></h1>
The pangramic word is: <span class=word>$Word</span>
<p>
$msg
<div class=description2>
For each of the 7 unique letters in the word we have done tallies of 'qualified' words.
A qualified word is one that:
<p>
<ul>
<li>includes the center letter
<li>is at least 4 letters long
<li>uses only the seven letters: <span class=green>\U@lets\E</span>
</ul>
<p>
Use the tallies to decide which letter should be the center one.
Then click on one of the center letters in the table below.
</div>
<p>
<h2>Qualified words that have been used in the NYT Puzzle:</h2>
<p>
$npangrams Pangram$pl: @pangrams
<p>
<table cellpadding=5
<tr>
<th valign=bottom>Center<br>Letter</th>
<th valign=bottom>Words</th>
<th valign=bottom>4 Letter</th>
<th valign=bottom>Score</th>
</tr>
EOH
for my $c (sort @lets) {
    print <<"EOH";
<tr>
<td class=let><a href='$log/cgi-bin/gwords.pl?word=$word&center=$c'>\U$c\E</a></td>
<td>$tot{$c}</td>
<td>$four{$c}</td>
<td>$score{$c}</td>
</tr>
EOH
}
print "</table>\n";

print <<"EOH";
<p>
<h2>Other qualified words (some rare and esoteric)</h2>
$bnpangrams pangram$bpl: @bpangrams
<p>
<table cellpadding=5
<tr>
<th valign=bottom>Center<br>Letter</th>
<th valign=bottom>Words</th>
<th valign=bottom>4 Letter</th>
<th valign=bottom>Additional<br>Score</th>
</tr>
EOH
for my $c (sort @lets) {
    print <<"EOH";
<tr>
<td class=let><a href='$log/cgi-bin/gwords.pl?word=$word&center=$c'>\U$c\E</a></td>
<td>$btot{$c}</td>
<td>$bfour{$c}</td>
<td>$bscore{$c}</td>
</tr>
EOH
}
print <<'EOH';
</table>
</body>
</html>
EOH
