#!/usr/bin/perl
use strict;
use warnings;

use CGI;
my $q = CGI->new();
my $uuid = $q->path_info();
$uuid =~ s{\A /}{}xms;

my $uuid_cookie = $q->cookie(
    -name    => 'uuid',
    -value    => $uuid,
    -expires => '+20y',
);
print $q->header(-cookie => $uuid_cookie);

use Bee_DBH qw/
    $dbh
/;
my $sth = $dbh->prepare(<<'EOS');

    SELECT name, location
      FROM bee_person
     WHERE uuid = ?

EOS
$sth->execute($uuid);
my ($name, $location) = $sth->fetchrow_array();
print "Name: $name, Location: $location";
