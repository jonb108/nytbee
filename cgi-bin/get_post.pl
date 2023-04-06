#!/usr/bin/env perl
use strict;
use warnings;
my ($p_date, $screen_name, $message) = @ARGV;

$message =~ s{--NEWLINE--}{<br>}xmsg;
use Time::Simple qw/
    get_time
/;
use Date::Simple qw/
    today
/;
use Bee_DBH qw/
    $dbh
/;
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
my $now = get_time();
$now->{minutes} -= 60;      # :(
    # probably a bug around midnight ...
$ins_sth->execute($screen_name,
                  today()->as_d8(), $now,
                  $p_date, $message);
