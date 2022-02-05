#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use BeeUtil qw/
    cgi_header
/;

# we will save the name, location, and word => clues
use Bee_DBH qw/
    $dbh
    add_update_person
/;

use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

my $q = CGI->new();
my $uuid = cgi_header($q);

my %params = $q->Vars();
my $person_id = add_update_person($uuid, $params{name}, $params{location});
$params{person_id} = $person_id;
$params{uuid} = $uuid;
my $clue_href = eval $params{clues};
$params{clues} = $clue_href;
$params{words} = [ split ' ', $params{words} ];
$params{pangrams} = [ split ' ', $params{pangrams} ];

my $dir = 'community_puzzles';
open my $in, '<', "$dir/last_num.txt";
my $n = <$in>;
close $in;
chomp $n;
++$n;
open my $out, '>', "$dir/last_num.txt";
print {$out} "$n\n";
close $out;

open my $puz, '>', "community_puzzles/$n.txt";
print {$puz} Dumper(\%params);
close $puz;

#
# now save the clues in the database
#
my $sth_ins_clue = $dbh->prepare(<<'EOS');

    INSERT
      INTO bee_clue
           (person_id, date, word, clue)
    VALUES (?, ?, ?, ?)

EOS
my $date = "CP$n";
for my $word (sort keys %{$clue_href}) {
    $sth_ins_clue->execute($person_id, $date,
                           $word, ucfirst $clue_href->{$word});
}

print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='http://logicalpoetry.com/nytbee/cgi_style.css'/>
</head>
<body>
Finished. &#128077;<br>
You have created an NYT Type Puzzle for the Hivemind Community.
<p>
Your puzzle is #$n.<br>
You will use the <span class=cmd>CP$n</span> command to open it.
<p>
You can now close this window.
</body>
</html>
EOH
