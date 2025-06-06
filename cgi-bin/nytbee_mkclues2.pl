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
    uniq_words
/;
use BeeClues qw/
    display_clues
/;
use Date::Simple qw/
    date
/;
use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;

my $q = CGI->new();
my $uuid = cgi_header($q);
# 9060f4f4-b124-11ee-b0d4-ac0cb0d5d1d5
my @f = split '-', $uuid;
if (@f == 5) {
    print <<'EOH';
<style>
body {
    font-size: 18pt;
    margin: .5in;
}
</style>
Sorry, you must set your own ID (with the ID command) in the puzzle before you can make clues!
EOH
    exit;
}

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
          # not sure why I did this
          #$clue =~ s{"}{&quot;}xmsg;
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
        unlink "clues/$date", "cluers/$date";
    }
    else {
        # remove $uuid from the hash
        $puzzle_has_clues{$date} = join '|',
                                   grep { $_ ne $uuid }
                                   split /\|/,
                                   $puzzle_has_clues{$date};
    }
    print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/css/cgi_style.css'/>
</head>
<body>
You offered no clues at all.   You can close this window.
EOH
    exit;
}
else {
    if (exists $puzzle_has_clues{$date}) {
        my @users = split /\|/, $puzzle_has_clues{$date};
        push @users, $uuid;
        $puzzle_has_clues{$date} = join '|', uniq_words @users;
    }
    else {
        $puzzle_has_clues{$date} = $uuid;
    }
    # 
    # write the text two files clues/$date and cluers/$date
    #
    my $sth1 = $dbh->prepare(<<'EOS');
    
    SELECT person_id, word, clue
      FROM bee_clue
     WHERE date = ?
 ORDER BY person_id

EOS
    $sth1->execute($date);
    my %clues;
    while (my ($person_id, $word, $clue) = $sth1->fetchrow_array()) {
        push @{$clues{$word}}, { person_id => $person_id, clue => $clue };
    }
    open my $out1, '>', "clues/$date"
        or die "no clues/$date";
    print {$out1} Dumper(\%clues);
    close $out1;

    my $sth2 = $dbh->prepare(<<'EOS');

    SELECT id, name
      FROM bee_person
     WHERE id IN (SELECT distinct person_id
                    FROM bee_clue, bee_person
                   WHERE date = ?) 
  ORDER BY id;

EOS
    $sth2->execute($date);
    my %cluers;
    while (my ($id, $name) = $sth2->fetchrow_array()) {
        $cluers{$id} = $name;
    }
    open my $out2, '>', "cluers/$date"
        or die "no clues/$date";
    print {$out2} Dumper(\%cluers);
    close $out2;

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
