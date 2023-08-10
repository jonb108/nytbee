#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my %admin;
tie %admin, 'DB_File', 'admin.dbm';
my %osx_usd_words_48;
tie %osx_usd_words_48, 'DB_File', 'osx_usd_words-48.dbm';
my %first_appeared;
tie %first_appeared, 'DB_File', 'first_appeared.dbm';
my %added_words;
tie %added_words, 'DB_File', 'added_words.dbm';
# key: date/cp#
# value: number of messages in the forum for this puzzle
my %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';

use Time::Simple qw/
    get_time
/;
use Date::Simple qw/
    today
/;
use Bee_DBH qw/
    $dbh
/;

my ($screen_name, $p_date, @words) = @ARGV;
if (! $admin{$screen_name}) {
    print "You are not an administrator.";
    exit;
}
my @new_words;
for my $w (@words) {
    if (exists $first_appeared{$w}) {
        print "\U$w\E: WAS used in the NYT Bee<br>";
    }
    elsif (exists $osx_usd_words_48{$w}) {
        print "\U$w\E: IS in the large lexicon<br>";
    }
    elsif (exists $added_words{$w}) {
        print "\U$w\E: is <i>already</i> an Added Word<br>";
    }
    else {
        $added_words{$w} = 1;
        push @new_words, $w;
    }
}
my $nwords = @new_words;
unless ($nwords) {
    exit;
}
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
$now->{minutes} -= 60;
my $pl = $nwords == 1? '': 's';
$ins_sth->execute($screen_name,
                  today()->as_d8(), $now->t24,
                  $p_date,
                  "Added Word$pl: "
                 . join(', ',
                        map { ucfirst }
                        @new_words),
                 );
++$num_msgs{$p_date};
