#!/usr/bin/perl
use strict;
use warnings;

use BeeUtil qw/
    slash_date
/;

my $uuid = shift;

use Bee_DBH qw/
    $dbh
/;

my $sth = $dbh->prepare(<<'EOS');

    SELECT id
      FROM bee_person
     WHERE uuid = ?

EOS
$sth->execute($uuid);
my ($id) = $sth->fetchrow_array();

my $sth_dates = $dbh->prepare(<<'EOH');

    SELECT distinct date
      FROM bee_clue
     WHERE person_id = ?
  ORDER BY date

EOH
$sth_dates->execute($id);
while (my ($date) = $sth_dates->fetchrow_array()) {
    print "$date\n";
}
