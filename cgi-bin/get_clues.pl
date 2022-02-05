#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use BeeUtil qw/
    cgi_header
    word_score
    trim
    my_today
    $log
/;
use Bee_DBH qw/
    get_person
/;

my $q = CGI->new();
my $uuid = cgi_header($q);

my $d8 = my_today->as_d8();
my ($person_id, $name, $location) = get_person($uuid);

# All may be null in case this is the first time
# the person is creating a puzzle or adding clues.
# we do this to get the $name and $location
# in case they _have_ been here before.
# 

use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

my %params = $q->Vars();

my %clues;
CLUE:
for my $k (grep { m! _clue \z!xms } keys %params) {
    my $w = $k;
    $w =~ s{_clue\z}{}xms;
    my $clue = ucfirst $params{$k};
    $clue =~ s{"}{'}xmsg;       # double quote is troublesome
                                # so just convert to single
                                # use HTML::Entities?
    if ($clue !~ m{\S}xms) {
        # no clue
        next CLUE;
    }
    $clues{$w} = $clue;
}
my $clues = Dumper(\%clues);
my $seven = $params{seven};
my $center = $params{center};
my $words = $params{words};
my $pangrams = $params{pangrams};
my @pangrams = map { ucfirst } split ' ', $pangrams;
my %is_pangram = map { $_ => 1 } split ' ', $pangrams;
my @words = split ' ', $words;
my $nwords = @words;
my $points = 0;
for my $w (@words) {
    $points += word_score($w, $is_pangram{$w});
}

print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
<script src="$log/nytbee/js/nytbee.js"></script>
</head>
<body>
<h1>Making an NYT Type<br>Spelling Bee Puzzle<br>Step <span class=red>5</span> <span class=step_name>Name and Location</span></h1>
<form name=form action=$log/cgi-bin/final_mkpuz.pl method=POST onsubmit="return check_name_location();">
<input type=hidden name=seven value='$seven'>
<input type=hidden name=center value='$center'>
<input type=hidden name=words value='$words'>
<input type=hidden name=pangrams value='$pangrams'>
<input type=hidden name=clues value="$clues">
<input type=hidden name=created value='$d8'>
Words: $nwords, Points: $points<br>
Pangrams: <span class=green>@pangrams</span><p>
Finally, provide some information about yourself.
<p>
<table cellpadding=5>

<tr>
<th>Name</th>
<td><input type=text name=name id=name value="$name" size=40></td>
</tr>

<tr>
<th>Location</th>
<td><input type=text name=location id=location value="$location" size=40></td>
</tr>

<tr>
<th>&nbsp;</th>
<td style="text-align: left"><button type=submit>Submit</button></td>
</tr>

</table>
</form>
</body>
</html>
<script>document.form.name.focus();</script>
</form>
EOH
