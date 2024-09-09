#!/usr/bin/perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();

my $word_file = $q->param('word_file') || 'nyt';
my $nyt_check = $word_file eq 'nyt'? 'checked': '';
my $osx_check = $word_file eq 'osx'? 'checked': '';
my $pattern = $q->param('pattern');

print $q->header(), <<"EOH";
<html>
<head>
<style>
body {
    margin: .5in;
}
body, input, button {
    font-size: 20pt;
    font-family: Arial;
}
button {
    background: lightgreen;
}
a {
    text-decoration: none;
    color: blue;
}
</style>
<body>
<form name=form action='https://ultrabee.org/cgi-bin/regexp.pl'>
Using <a target=_blank href='https://perldoc.perl.org/perlretut'>Perl Regular Expressions</a> search the words in:
<ul>
<label><input type=radio name='word_file' value='nyt' $nyt_check> NYT Spelling Bees</label><br>
&nbsp;&nbsp;or<br>
<label><input type=radio name='word_file' value='osx' $osx_check> Large Lexicon from OSX (with <= 7 unique characters and length >= 4)</label>
</ul>
for this pattern: <input name=pattern type=text size=20 value='$pattern'>
<button>Go</button> (or hit Return)<br>
</form>
<body>
</html>
<script>document.form.pattern.focus();</script>
EOH
use DB_File;
if ($q->param('pattern')) {
    my @words;
    if ($word_file eq 'osx') {
        shift;
        my %osx_usd_words_47;
        tie %osx_usd_words_47, 'DB_File', 'osx_usd_words-47.dbm';
        @words = sort grep { m{$pattern}xmsi } keys %osx_usd_words_47;
    }
    else {
        my %first_appeared;
        tie %first_appeared, 'DB_File', 'first_appeared.dbm';
        @words = sort grep { m{$pattern}xmsi } keys %first_appeared;
    }
    my $nwords = @words;
    my $pl = $nwords == 1? '': 's';
    local $" = "<br>\n";
    print "$nwords word$pl<p>@words\n";
}
