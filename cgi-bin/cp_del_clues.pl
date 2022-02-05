#!/usr/bin/perl
use strict;
use warnings;

use CGI;
my $q = CGI->new();
my $n = $q->path_info();
$n =~ s{\A /}{}xms;

use Bee_DBH qw/
    $dbh
/;

# clear old clues for this community puzzle
my $sth_clear = $dbh->prepare(<<'EOS');
    
    DELETE
      FROM bee_clue
     WHERE date = ?

EOS
$sth_clear->execute("CP$n");

print $q->header(); # so no error
