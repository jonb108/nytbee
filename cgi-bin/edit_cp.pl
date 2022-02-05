#!/usr/bin/perl
use strict;
use warnings;

use CGI;
my $q = CGI->new();
my $uuid = $q->cookie('uuid');
if (! $uuid) {
    # only load this module if it is needed
    require UUID::Tiny;
    $uuid = UUID::Tiny::create_uuid_as_string(1);
}
my $uuid_cookie = $q->cookie(
    -name    => 'uuid',
    -value    => $uuid,
    -expires => '+20y',
);
print $q->header(-cookie => $uuid_cookie);
my $n = $q->path_info();
$n =~ s{\A /}{}xms;

use BeeUtil qw/
    uniq_chars
    $log
/;
my $fname = "community_puzzles/$n.txt";

if (! -f $fname) {
    print "no such puzzle: CP$n\n";
    exit;
}
my $href = do $fname;

if ($uuid ne $href->{uuid}) {
    print "you did not create CP$n\n";
    exit;
}

my $seven = $href->{seven};
my $center = $href->{center};
my @lets = uniq_chars($seven);
my %was_checked = map { $_ => 1 } @{$href->{words}};
my $regex = qr{[^$seven]}xms;
print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
</head>
<body>
<h1>Editing CP$n <span class=step_name>Words</span></h1>
For the seven letters <span class=center>\U$seven\E</span> and center letter <span class=center>\U$center\E</span> we have identified the qualified words AND the words you chose before.
<p>
Check the words you want to include in the puzzle and press Submit.  Make sure you include at least one pangram. They are colored <span class=red>red</span>.

<p>
<form action=$log/cgi-bin/edit_cp_clues.pl method=POST>
<input type=hidden name=CPn value=$n>
<h2>Qualified words used in previous NYT Bee Puzzles:</h2>
You can, of course, UNcheck these words, if you wish.
<button type=submit>Submit</button>
<p>
EOH
open my $in, '<', 'nyt-words.txt';
LINE:
while (my $line = <$in>) {
    chomp $line;
    if ($line !~ $regex) {
        if (index($line, $center) >= 0) {
            my $Line = ucfirst $line;
            my $checked = '';
            if ($was_checked{$line}) {
                $checked = ' checked';
                delete $was_checked{$line};
            }
            print "<input type=checkbox name=ok value=$line$checked>&nbsp; ";
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
print <<'EOH';
<h2>More words (qualified but some are rare and esoteric):</h2>
Surprisingly, there are many common ordinary words that have not yet been used in any of the NYT puzzles.
<button type=submit>Submit</button>
<p>
EOH
open my $in2, '<', 'other-words.txt';
LINE:
while (my $line = <$in2>) {
    chomp $line;
    if ($line !~ $regex) {
        if (index($line, $center) >= 0) {
            my $Line = ucfirst $line;
            my $checked = '';
            if ($was_checked{$line}) {
                $checked = ' checked';
                delete $was_checked{$line};
            }
            print "<input type=checkbox name=ok value=$line$checked>&nbsp; ";
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

# the words in @words that were not
# checked must be the 'other' words.
#
my @other_words = map { ucfirst } keys %was_checked;
print <<"EOH";
<p>
Other qualified words to include:<br><input type=text size=40 name=other_words value='@other_words'>
<p>
<button type=submit>Submit</button>
</form>
</body>
</html>
EOH
