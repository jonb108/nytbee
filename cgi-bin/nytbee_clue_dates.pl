#!/usr/bin/perl
use strict;
use warnings;

use BeeUtil qw/
    slash_date
/;

# no need to use CGI
print "Content-Type: text/html; charset=ISO-8859-1\n\n";

my $uuid = $ENV{PATH_INFO};
$uuid =~ s{\A /}{}xms;

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
my @dates;
while (my ($date) = $sth_dates->fetchrow_array()) {
    push @dates, $date;
}
# may be some are community puzzles ...
print join '<br>',
      map {
          /^\d/? slash_date($_): $_;
      }
      @dates;
