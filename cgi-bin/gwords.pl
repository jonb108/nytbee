#!/usr/bin/perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
print $q->header();

use BeeUtil qw/
    uniq_chars
    $log
/;

my $word = lc $q->param('word');
my $Word = ucfirst $word;
my $used_word = 0;

my @lets = uniq_chars($word);
my $center = $q->param('center');
my $seven = join '', @lets;
my $regex = qr{[^$seven]}xms;
print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
</head>
<body>
<h1>Making an NYT Type<br>Spelling Bee Puzzle<br>Step <span class=red>3</span> <span class=step_name>Words</span></h1>
For the pangramic word <span class=word>$Word</span> and center letter <span class=center>\U$center\E</span> we have identified the qualified words.
<p>
Check the words you want to include in the puzzle and press Submit at the bottom.  Make sure you include at least one pangram. They are colored <span class=red>red</span>.

<p>
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
    if ($line !~ $regex) {
        if (index($line, $center) >= 0) {
            if ($line eq $word) {
                $used_word = 1;
            }
            my $Line = ucfirst $line;
            print "<input type=checkbox name=ok value=$line checked>&nbsp; ";
            my @uchars = uniq_chars($line);
            if (@uchars == 7) {
                print "<span class=red>$Line</span>";
            }
            else {
                print $Line;
            }
            print "<br>\n";
        }
    }
}
close $in;
print "<h2>More words (qualified but some are rare and esoteric):</h2>\n";
print "Surprisingly, there are many common ordinary words that have not yet been used in any of the NYT puzzles.<p>\n";
open my $in2, '<', 'other-words.txt';
LINE:
while (my $line = <$in2>) {
    chomp $line;
    if ($line !~ $regex) {
        if (index($line, $center) >= 0) {
            if ($line eq $word) {
                $used_word = 1;
            }
            my $Line = ucfirst $line;
            print "<input type=checkbox name=ok value=$line>&nbsp; ";
            my @uchars = uniq_chars($line);
            if (@uchars == 7) {
                print "<span class=red>$Line</span>";
            }
            else {
                print $Line;
            }
            print "<br>\n";
        }
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
