#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use BeeUtil qw/
    cgi_header
    $log
    ymd
/;

# we will save the name, location, and word => clues
use Bee_DBH qw/
    $dbh
    add_update_person
/;

use File::Slurp qw/
    edit_file
    write_file
    append_file
/;

use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

my $q = CGI->new();
my $uuid = cgi_header($q);

my %params = $q->Vars();
$params{publish} |= '';   # since unchecked boxes are not sent...

my $person_id = add_update_person($uuid, $params{name}, $params{location});
$params{person_id} = $person_id;
$params{uuid} = $uuid;
my $clue_href = eval $params{clues};
$params{clues} = $clue_href;
$params{words} = [ split ' ', $params{words} ];
$params{pangrams} = [ split ' ', $params{pangrams} ];

my $dir = 'community_puzzles';
my $n;
edit_file { $n = $_ = $_+1 } "$dir/last_num.txt";
write_file "$dir/$n.txt", Dumper(\%params);

append_file 'beelog/' . ymd(), substr($uuid, 0, 11) . " creating CP$n\n";

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
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
</head>
<body>
You have created Community Puzzle #$n.
EOH
if (! $params{publish}) {
    print <<"EOH";
<p>
It is not yet ready to share with the HiveMind.
<p>
To make it available enter 'YCP', choose this puzzle,<br>
edit it, finalize the words, clues, and title/description<br>
and then check 'Ready to Publish'.
<p>
You can close this window.
EOH
}
else {
    print <<"EOH";
<p>
You will use the <span class=cmd>CP$n</span> command to open it.<br>
<p>
You can also open it with this link which you can share:
<ul>
    <a href='$log/cgi-bin/nytbee.pl/CP$n'>$log/cgi-bin/nytbee.pl/CP$n</a>
</ul>
EOH
}
print <<'EOH';
</body>
</html>
EOH
