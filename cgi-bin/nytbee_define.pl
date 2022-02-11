#!/usr/bin/perl
use strict;
use warnings;

use LWP::Simple qw/
    get
/;

print "Content-Type: text/html; charset=ISO-8859-1\n\n";

sub define {
    my ($word) = @_;

    my ($html, @defs);

    # merriam-webster
    $html = get "https://www.merriam-webster.com/dictionary/$word";
    # to catch an adequate definition for 'bought':
    @defs = $html =~  m{meaning\s+of\s+$word\s+is\s+(.*?)[.]\s+How\s+to}xmsi;
    push @defs, $html =~ m{dtText(.*?)\n}xmsg;
    if (! @defs) {
        # some definitions (like 'from') use a different format
        # no clue why
        push @defs, ($html =~ m{"unText">(.*?)</span>}xmsg);
    }
    for my $def (@defs) {
        $def =~ s{\A \s*|\s* \z}{}xmsg;
        $def =~ s{<[^>]*>}{}xmsg;   # strip tags
        $def =~ s{\A ">}{}xms;    # stray chars from somewhere
        $def =~ s{.*:\s+}{}xms;
    }
    if (! @defs) {
        # collins
        $html = get "https://www.lexico.com/en/definition/$word";
        @defs = $html =~ m{Lexical\s+data\s+-\s+en-us">(.*?)</span>}xmsg;
    }
    # sometimes the definition is duplicated so ...
    my %seen;
    my @tidied_defs;
    DEF:
    for my $d (@defs) {
        $d =~ s{<[^>]*>}{}xmsg; # excise any tags
        $d =~ s{[^[:print:]]}{}xmsg; # excise any non-printing chars
        if ($seen{$d}++) {
            next DEF;
        }
        push @tidied_defs, $d;
    }
    @tidied_defs = splice @tidied_defs, 0, 5;
    my $Word = ucfirst $word;
    print <<"EOH";
<html>
<head>
<title>Definition of $Word</title>
<style>
body {
    font-family: Arial;
    margin: 5mm;
}
</style>
</head>
<body>
<h2>Definition of $Word</h2>
<ul>
EOH
    print join '',
          map {
              "<li>$_</li>\n";
          }
          @tidied_defs;
    print "</ul>";
}

my $word = $ENV{PATH_INFO};
$word =~ s{\A /}{}xms;

define($word);

print <<'EOH';
</body>
</html>
EOH
