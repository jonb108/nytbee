#!/usr/bin/env perl
use strict;
use warnings;
use BeeUtil qw/
    uniq_chars
/;
use DB_File;
my %osx_usd_words_48;
tie %osx_usd_words_48, 'DB_File', 'osx_usd_words-48.dbm';
my %first_appeared;
tie %first_appeared, 'DB_File', 'first_appeared.dbm';
my %added_words;
tie %added_words, 'DB_File', 'added_words.dbm';
my %missing_words;
tie %missing_words, 'DB_File', 'missing_words.dbm';
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

my ($screen_name, $p_date, $seven, @words) = @ARGV;
my @new_words;
for my $w (@words) {
    my $W = '<span class=red>' . uc($w) . '</span>';
    my $s = $w;
    $s =~ s{[$seven]}{}xmsg;
    if (uniq_chars($s) > 1) {
        print "$W: not a valid Bonus word for this puzzle<br>";
    }
    elsif (exists $first_appeared{$w}) {
        print "$W: WAS used in the NYT Bee<br>";
    }
    elsif (exists $osx_usd_words_48{$w}) {
        print "$W: IS in the large lexicon<br>";
    }
    elsif (exists $added_words{$w}) {
        print "$W: is <i>already</i> an Added Word<br>";
    }
    else {
        push @new_words, $w;
    }
}
my $nwords = @new_words;
if (!$nwords) {
    exit;
}
for my $w (@new_words) {
    $missing_words{$w} = $p_date;
}
my $pl = $nwords == 1? '': 's';
print "Got $nwords word$pl.";
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
                  "Missing Word$pl: "
                 . join(' ',
                        map { ucfirst }
                        @new_words),
                 );
++$num_msgs{$p_date};
