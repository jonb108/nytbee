#!/usr/bin/perl
use strict;
use warnings;

use BeeUtil qw/
    uniq_chars
/;

sub error {
    my ($msg) = @_;
    print <<"EOH";
<style>
body {
    margin: .5in;
    font-size: 18pt;
}
</style>
$msg
EOH
    exit;
}

# a poor man's CGI:
print "Content-Type: text/html; charset=ISO-8859-1\n\n";
my $word = $ENV{PATH_INFO};
$word =~ s{\A /}{}xms;

if ($word !~ m{\S}xms) {
    error "Missing word to search for...";
}

my @chars = uniq_chars lc $word;
if (@chars > 7) {
    error "Sorry, there are more than 7 unique characters in $word.";
}

my @pangrams;

my $bee = '/home4/logical9/www/ultrabee';

sub get_pangrams {
    my ($f) = @_;
    my @pangrams;
    open my $in, '<', "$bee/$f"
        or die "cannot open $bee/$f: $!\n";
    LINE:
    while (my $line = <$in>) {
        if ($line eq "<pre>\n") {
            last LINE;
        }
    }
    LINE:
    while (my $line = <$in>) {
        chomp $line;
        if ($line =~ m{\A <div .*>([a-z]+) \z}xms) {
            $line = $1;
        }
        elsif ($line =~ m{\A <}xms) {
            next LINE;
        }
        for my $c (@chars) {
            if (index($line, $c) < 0) {
                next LINE;
            }
        }
        push @pangrams, $line;
    }
    return \@pangrams;
}
# 3 files of pangramic words in $bee/:
my $nyt_pangrams_aref = get_pangrams('nyt_pangrams.html');
my $goo_pangrams_aref = get_pangrams('goo10k-7-nyt.html');
my $osx_pangrams_aref = get_pangrams('osx_usd_words-7-nyt-goo.html');

print <<"EOH";
<html>
<head>
<style>
body {
    margin: .5in;
    font-family: Arial;
    font-size: 18pt;
}
.word {
    color: red;
    font-size: 34pt;
}
.words {
    word-spacing: 10px;
}
</style>
</head>
<body>
<h2>Pangramic Words with <span class=word>$word</span>:</h2>
EOH
print "<h2>NYT puzzles:</h2>\n<div class=words>@$nyt_pangrams_aref</div>\n";
print "<h2>10,000 Common Words:</h2>\n<div class=words>@$goo_pangrams_aref</div>\n";
print "<h2>Large Lexicon:</h2>\n<div class=words>@$osx_pangrams_aref</div>\n";
