#!/usr/bin/env perl
use strict;
use warnings;
use Bee_DBH qw/
    $dbh
/;
my $get_sth = $dbh->prepare(<<'EOS');

    SELECT *
      FROM forum
     WHERE id = ?

EOS
my $del_sth = $dbh->prepare(<<'EOS');

    DELETE
      FROM forum
     WHERE id = ?

EOS
use DB_File;
# key: date/cp#
# value: number of messages in the forum for this puzzle
my %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';

my ($id, $screen_name) = @ARGV;
$get_sth->execute($id);
my $href = $get_sth->fetchrow_hashref();
if (! $href) {
    # no longer exists
    exit;
}
if ($href->{screen_name} eq $screen_name) {
    $del_sth->execute($id);
}
else {
    print "Not your post!\n";
}
