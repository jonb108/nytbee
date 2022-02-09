#!/usr/bin/perl
use strict;
use warnings;

my $n = shift;

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
