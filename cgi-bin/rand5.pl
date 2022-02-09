#!/usr/bin/perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
print $q->header();
my $n = substr($q->path_info(), 1);
my $fname = $n == 1? 'nyt_pangrams.html'
           :$n == 2? 'goo10k-7-nyt.html'
           :         'osx_usd_words-7-nyt-goo.html'
           ;
my @words;
open my $in, '<', "/home4/logical9/www/nytbee/$fname";
LINE:
while (my $line = <$in>) {
    if ($line eq "<pre>\n") {
        last LINE;
    }
}
while (my $line = <$in>) {
    chomp $line;
    push @words, $line =~ m{>([a-z]+) \z}xms? $1: $line;
}
close $in;
pop @words for 1 .. 3;  # the last 3 lines in the file
print <<"EOH";
<html>
<head>
<style>
body {
    font-family: Arial;
    font-size: 18pt;
    margin: 10mm;
}
.more {
    margin-left: 2in;
    text-decoration: none;
    color: blue;
}
</style>
</head>
<body>
EOH
my @rand;
push @rand, $words[rand @words] for 1 .. 5;
my $title = $n == 1? 'NYT Puzzles'
           :$n == 2? '10k Common Words'
           :         'Large Lexicon'
           ;
print "<h4>$title</h4>\n";
print map {
          "$_<br>\n"
      }
      sort
      @rand;
print <<"EOH";
<a id=more
   class=more
   href='https://logicalpoetry.com/cgi-bin/rand5.pl/$n'
>More</a>
<script>document.getElementById('more').focus();</script>
EOH
