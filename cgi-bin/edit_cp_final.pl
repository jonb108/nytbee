#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use BeeUtil qw/
    cgi_header
    $log
    ymd
    puzzle_info
/;

# we will save the name, location
use Bee_DBH qw/
    $dbh
    add_update_person
/;

use File::Slurp qw/
    write_file
    append_file
/;

use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 1;

my $q = CGI->new();
my $uuid = cgi_header($q);

my %params = $q->Vars();
$params{publish} |= '';   # since unchecked boxes are not sent...

my $n = $params{CPn};

my $dir = 'community_plus';
my $href = do "$dir/$n.txt";

# save a possibly different name and location in the database
add_update_person($uuid, $params{name}, $params{location});

for my $f (qw/ name location title description publish /) {
    $href->{$f} = $params{$f};
}

# an lvalue of a hash slice!
@$href{qw/
    nwords max_score
    npangrams nperfect
    bingo gn4l gn4l_np
/} = puzzle_info($href->{words}, $href->{pangrams});
write_file "$dir/$n.txt", Dumper($href);

append_file 'beelog/' . ymd(), substr($uuid, 0, 11) . " edited CP$n\n";

print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/css/cgi_style.css'/>
</head>
<body>
You have edited your Community Puzzle #$n.
EOH
if (! $href->{publish}) {
    print <<"EOH";
<p>
It is not yet ready to share with the HiveMind.
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
<p>
You can close this window.
</body>
</html>
EOH
