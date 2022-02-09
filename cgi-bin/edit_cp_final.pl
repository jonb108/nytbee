#!/usr/bin/perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
print $q->header();

use BeeUtil qw/
    my_today
    $log
/;

my %params = $q->Vars();

my $CPn = $params{CPn};
my $fname = "community_puzzles/$CPn.txt";
my $href = do $fname;
# and now replace $href->{words}
#                 $href->{clues}
#                 $href->{pangrams}
#             and $href->{created}
# all else is the same
$href->{created}  = my_today->as_d8();
$href->{words}    = [ split ' ', $params{words}    ];
$href->{pangrams} = [ split ' ', $params{pangrams} ];

# for clearing and inserting clues in bee_clue
my $person_id = $href->{person_id};
my $date = "CP$CPn";

use Bee_DBH qw/
    $dbh
/;
my $sth_clear_clues = $dbh->prepare(<<'EOS');

    DELETE
      FROM bee_clue
     WHERE person_id = ?
       AND date = ?

EOS
$sth_clear_clues->execute($person_id, $date);

my $sth_ins = $dbh->prepare(<<'EOS');

    INSERT
      INTO bee_clue
           (person_id, date, word, clue)
    VALUES (?, ?, ?, ?)

EOS

my %clues;
CLUE:
for my $k (grep { m! _clue \z!xms } keys %params) {
    my $word = $k;
    $word =~ s{_clue\z}{}xms;
    my $clue = $params{$k};
    $clue =~ s{"}{'}xmsg;       # double quote is troublesome
                                # so just convert to single
                                # use HTML::Entities?
    if ($clue !~ m{\S}xms) {
        # no clue
        next CLUE;
    }
    $sth_ins->execute($person_id, $date, $word, ucfirst $clue);
    $clues{$word} = $clue;
}
$href->{clues} = \%clues;

use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;
open my $out, '>', $fname;
print {$out} Dumper($href);
close $out;

print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
</head>
<body>
Finished editing CP$CPn.
You can close this window.
</body>
</html>
EOH