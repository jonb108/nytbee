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

    SELECT id, name
      FROM bee_person
     WHERE id IN (SELECT distinct person_id
                    FROM bee_clue, bee_person
                   WHERE date = ?) 
  ORDER BY id;

EOS
$sth->execute($date);
my %cluers;
while (my ($id, $name) = $sth->fetchrow_array()) {
    $cluers{$id} = $name;
}
use Data::Dumper;
$Data::Dumper::Terse = 1;
print Dumper(\%cluers);
