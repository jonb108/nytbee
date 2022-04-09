#!/usr/bin/perl
use strict;
use warnings;

# a poor man's database
use DB_File;
my %puzzle_has_clues;
tie %puzzle_has_clues, 'DB_File', 'nyt_puzzle_has_clues.dbm';

use CGI;
use BeeUtil qw/
    cgi_header
    trim
    $log
    ymd
/;
use BeeClues qw/
    display_clues
/;
use Date::Simple qw/
    date
/;

my $q = CGI->new();
my $uuid = cgi_header($q);

my $date = $q->param('date');       #  hidden field

open my $out, '>>', 'beelog/' . ymd();
print {$out} substr($uuid, 0, 11) . " mkclues2 $date\n";
close $out;

my $show_date = date($date)->format("%B %e, %Y");
my $all_words = $q->param('all_words');
my $name = $q->param('name');
my $location = $q->param('location');

my %params = $q->Vars();

my %clue_for
    = map {
          my $w = $_;
          my $clue = trim($params{$w});
          $clue =~ s{"}{'}xmsg;
          $w =~ s{_clue\z}{}xms;
          $w => ucfirst $clue
      }
      grep {
          m{_clue\z}xms
          &&
          $params{$_} =~ m{\S}xms
      }
      keys %params;

=comment

insert into mysql database
two tables - bee_person, bee_clue
bee_person  (id, uuid, name)
bee_clue    (person_id, date, word, clue)
        primary key is (person_id, date, word)

1 - update any existing person record for the person
2 - clear all clues for this person and date
3 - insert all word, clue

=cut

use Bee_DBH qw/
    $dbh
    add_update_person
/;

my $person_id = add_update_person($uuid, $name, $location);

# clear old clues from this person for this date
my $sth_clear = $dbh->prepare(<<'EOS');
    
    DELETE
      FROM bee_clue
     WHERE person_id = ?
       AND date = ?

EOS
$sth_clear->execute($person_id, $date);

# insert clues into the database
my $ins_clue_sth = $dbh->prepare(<<'EOS');

    INSERT
      INTO bee_clue
           (person_id, date, word, clue)
    VALUES (?, ?, ?, ?)

EOS
my $nclues = 0;
for my $w (keys %clue_for) {
    $ins_clue_sth->execute($person_id, $date, $w, $clue_for{$w});
    ++$nclues;
}
if (! $nclues) {
    # so we cleared out all of our clues
    # has anyone else offered clues?
    # if not, delete the entry in %puzzle_has_clues
    #
    my $sth_clues = $dbh->prepare(<<'EOS');

        SELECT word, clue
          FROM bee_clue
         WHERE date = ?

EOS
    $sth_clues->execute($date);
    my ($word, $clue) = $sth_clues->fetchrow_array();
    if (! $word) {
        # we must have been the only one
        delete $puzzle_has_clues{$date};
    }
    else {
        $puzzle_has_clues{$date} = join '|',
                                   grep { $_ ne $uuid }
                                   split /\|/,
                                   $puzzle_has_clues{$date};
    }
    print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
</head>
<body>
You offered no clues at all.   You can close this window.
EOH
    exit;
}
else {
    if (exists $puzzle_has_clues{$date}) {
        $puzzle_has_clues{$date} .= "|$uuid";
    }
    else {
        $puzzle_has_clues{$date} = $uuid;
    }
    display_clues(first          => 1,
                  all_words      => $all_words,
                  format         => 1,
                  show_date      => $show_date,
                  date           => $date,
                  person_id      => $person_id,
                  name           => $name,
                  clue_for_href  => \%clue_for,
                  was_found_href => {},
    );
}
