#!/usr/bin/env perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
print $q->header(
    -access_control_allow_origin => '*',
);
my $id = $q->param('id');
print "msg$id";
use Bee_DBH qw/
    $dbh
/;
my $upd_sth = $dbh->prepare(<<'EOS');
    UPDATE forum
       SET flagged = 'Y'
     WHERE id = ?
EOS
$upd_sth->execute($id);
