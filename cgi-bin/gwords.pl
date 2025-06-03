#!/usr/bin/perl
use strict;
use warnings;

use BeeUtil qw/
    uniq_chars
    $log
    ymd
    cgi_header
/;

use CGI;
my $q = CGI->new();
my $uuid = cgi_header($q);

my $word = lc $q->param('word');
my $Word = ucfirst $word;
my $used_word = 0;

my @lets = uniq_chars($word);
my $center = $q->param('center');

open my $out, '>>', 'beelog/' . ymd();
print {$out} substr($uuid, 0, 11) . " making puzzle with word '$Word' and center letter \U$center\n";
close $out;

my $seven = join '', @lets;
my $regex = qr{[^$seven]}xms;
print <<"EOH";
<html>
<head>
<title>
UltraBee - Creating a Community Puzzle - Words
</title>
<link rel='stylesheet' type='text/css' href='$log/css/cgi_style.css'/>
</head>
<body>
<h1>Creating a<br>Community Puzzle<br>Step <span class=red>3</span> <span class=step_name>Words</span></h1>
<div class=description2>
For the pangramic word <span class=word>$Word</span> and center letter <span class=center>\U$center\E</span> we have identified the qualified words.
<p>
Check the words you want to include in the puzzle and press Submit at the bottom.  Make sure you include at least one pangram. They are colored <span class=red>red</span>.
</div>
<form action=$log/cgi-bin/clues.pl method=POST>
<input type=hidden name=seven value=$seven>
<input type=hidden name=center value=$center>
<h2>Qualified words used in previous NYT Bee Puzzles:</h2>
You can, of course, UNcheck these words, if you wish.
<p>
EOH
open my $in, '<', 'nyt-words.txt';
LINE:
while (my $line = <$in>) {
    chomp $line;
    if ($line !~ $regex && index($line, $center) >= 0) {
        if ($line eq $word) {
            $used_word = 1;
        }
        my $Line = ucfirst $line;
        print "<label><input type=checkbox name=ok value=$line checked>&nbsp; ";
        my @uchars = uniq_chars($line);
        if (@uchars == 7) {
            print "<span class=red>$Line</span>";
        }
        else {
            print $Line;
        }
        print "</label><br>\n";
    }
}
close $in;
print "<h2>More words (qualified but some are rare and esoteric):</h2>\n";
print "<div class=description2>Surprisingly, there are many common ordinary words that have not yet been used in any of the NYT puzzles.  This is likely due to the letter S not being allowed in NYT puzzles or the prohibition against E and R appearing together.</div><p>\n";
open my $in2, '<', 'other-words.txt';
LINE:
while (my $line = <$in2>) {
    chomp $line;
    if ($line !~ $regex && index($line, $center) >= 0) {
        if ($line eq $word) {
            $used_word = 1;
        }
        my $Line = ucfirst $line;
        print "<label><input type=checkbox name=ok value=$line>&nbsp; ";
        my @uchars = uniq_chars($line);
        if (@uchars == 7) {
            print "<span class=red>$Line</span>";
        }
        else {
            print $Line;
        }
        print "</label><br>\n";
    }
}
close $in2;
my $other = $used_word? '': ucfirst $word;
print <<"EOH";
<p>
Other qualified words to include:<br><input type=text size=40 name=other_words value='$other'>
<p>
<button type=submit>Submit</button>
</form>
</body>
</html>
EOH
