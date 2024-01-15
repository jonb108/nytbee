#!/usr/bin/perl
use strict;
use warnings;
use BeeUtil qw/
    get_html
/;
use DB_File;
my %definition_of;
tie %definition_of, 'DB_File', 'definition_of.dbm';

my $word = $ENV{PATH_INFO};
$word =~ s{\A /}{}xms;
my $WORD = uc $word;

if (! exists $definition_of{$word}) {
    my $html = get_html("https://www.wordnik.com/words/$word");
    my ($def) = $html =~ m{[<]meta\s content='$word:\ ([^']*)'}xms;
    if (! $def) {
        $def = "No definition";
    }
    $def =~ s{[<][^>]*[>]}{}xmsg;
    $def =~ s{[&][#]39;}{'}xmsg;
    $def =~ s{$word}{'*' x length($word)}xmsegi;
    $def =~ s{[^[[:ascii]]]}{}xmsg;
    $definition_of{$word} = $def;
}

print "Content-Type: text/html; charset=ISO-8859-1\n\n";

    print <<"EOH";
<html>
<head>
<title>$WORD</title>
<script src="https://logicalpoetry.com/nytbee/js/nytbee7.js"></script>
<style>
body {
    font-family: Arial;
    margin: 5mm;
}
.cursor_pointer {
    cursor: pointer;
}
</style>
</head>
<body>
<span class=cursor_pointer onclick="full_def('$word');">$WORD:
<ul style='margin-top: 0px'>
$definition_of{$word}
</ul>
</span>
</body>
</html>
EOH
