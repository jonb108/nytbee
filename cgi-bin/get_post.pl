#!/usr/bin/env perl
use strict;
use warnings;

use Time::Simple qw/
    get_time
/;
use Date::Simple qw/
    today
/;
use Bee_DBH qw/
    $dbh
/;
use DB_File;
# key: date/cp#
# value: number of messages in the forum for this puzzle
my %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';

my $ins_sth = $dbh->prepare(<<'EOS');

    INSERT
      INTO forum
         (screen_name,
          m_date, m_time,
          p_date, message,
          flagged)
     VALUES (?,
             ?, ?,
             ?, ?,
             '');

EOS
my ($p_date, $screen_name, $message) = @ARGV;
my $now = get_time();
$now->{minutes} -= 60;
$ins_sth->execute($screen_name,
                  today()->as_d8(), $now->t24,
                  $p_date, $message);
++$num_msgs{$p_date};
