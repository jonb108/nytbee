#!/usr/bin/perl
use strict;
use warnings;

use CGI;
my $q = CGI->new();
print $q->header();
my %param = $q->Vars();

use BeeClues qw/
    display_clues
/;

use Date::Simple qw/
    date
    today
/;

my $first = $param{first};
my $all_words = $param{all_words};
my $date = $param{date};
if (! $date) {
    my ($hour) = (localtime)[2];
    my $today = today();
    if ($hour < 1) {
        # the machine is in MST
        # and the "next day" doesn't start until 3:00 AM EST
        --$today;
    }
    $date = $today->as_d8();
}
my $format = $param{format};
my $person_id = $param{person_id};
if (! $person_id) {
    $person_id = 284;   # kitt
}
my %was_found = map { $_ => 1 }
                split ' ', $param{found};
# to be set:
my $show_date;
my $name;
my %clue_for;

use Bee_DBH qw/
    $dbh
/;

if (my ($ncp) = $date =~ m{\A CP(\d+) \z}xms) {
    # community puzzles don't need a database connection
    # some way to avoid the $dbh initialization?
    $show_date = $date;
    my $href = do "community_plus/$ncp.txt";
    $name = $href->{name};
    %clue_for = %{$href->{clues}};
}
else {
    $show_date = date($date)->format("%B %e, %Y");
    my $sth = $dbh->prepare(<<'EOS');

    SELECT name
      FROM bee_person
     WHERE id = ?

EOS
    $sth->execute($person_id);
    ($name) = $sth->fetchrow_array();

    my $sth_clues = $dbh->prepare(<<'EOS');

    SELECT word, clue
      FROM bee_clue
     WHERE date = ?
       AND person_id = ?

EOS
    $sth_clues->execute($date, $person_id);
    while (my ($word, $clue) = $sth_clues->fetchrow_array()) {
        $clue_for{$word} = $clue;
    }
}
display_clues(first          => $first,
              all_words      => $all_words,
              format         => $format,
              show_date      => $show_date,
              date           => $date,
              person_id      => $person_id, 
              name           => $name,
              clue_for_href  => \%clue_for,
              was_found_href => \%was_found,
);
