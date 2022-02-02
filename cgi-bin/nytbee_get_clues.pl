#!/usr/bin/perl
use strict;
use warnings;

print "Content-Type: text/html; charset=ISO-8859-1\n\n";

my $date = $ENV{PATH_INFO};
$date =~ s{\A /}{}xms;

use Bee_DBH qw/
    $dbh
/;

my $sth = $dbh->prepare(<<'EOS');
    
    SELECT person_id, word, clue
      FROM bee_clue
     WHERE date = ?
 ORDER BY person_id

EOS
$sth->execute($date);
my %clues;
while (my ($person_id, $word, $clue) = $sth->fetchrow_array()) {
    push @{$clues{$word}}, { person_id => $person_id, clue => $clue };
}
use Data::Dumper;
$Data::Dumper::Terse = 1;
print Dumper(\%clues);
