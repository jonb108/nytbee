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
    ymd
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

open my $out, '>>', 'beelog/' . ymd();
print {$out} substr($uuid, 0, 11) . " getting clues for 7: $seven\n";
close $out;

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
<h1>Creating a<br>Community Puzzle<br>Step <span class=red>5</span> <span class=step_name>Name and Location</span></h1>
<form name=form action=$log/cgi-bin/final_mkpuz.pl method=POST onsubmit="return check_name_location();">
<input type=hidden name=seven value='$seven'>
<input type=hidden name=center value='$center'>
<input type=hidden name=words value='$words'>
<input type=hidden name=pangrams value='$pangrams'>
<input type=hidden name=clues value="$clues">
<input type=hidden name=created value='$d8'>
Words: $nwords, Points: $points<br>
Pangrams: <span class=green>@pangrams</span><p>
<div style="width: 650px">
Provide some information about yourself.
Optionally, add a title and description for your puzzle.
If you'd like, you can give contact information so
puzzlers can thank you for your contribution (and ask why a given word
was or was not included!).
</div>
<p>
<table cellpadding=5>

<tr>
<th>Name</th>
<td class=left><input type=text name=name id=name value="$name" size=40></td>
</tr>

<tr>
<th>Location</th>
<td class=left><input type=text name=location id=location value="$location" size=40></td>
</tr>

<tr>
<th>Title</th>
<td class=left><input type=text name=title id=title size=40></td>
</tr>

<tr>
<th valign=top>Description</th>
<td class=left><textarea name=description id=description rows=5 cols=32></textarea></td>
</tr>

<tr>
<th>Ready to<br>Publish?</th>
<td class=left valign=center><input type=checkbox name=publish id=publish value=yes></td>
</tr>

<tr>
<th>&nbsp;</th>
<td class=left><button type=submit>Submit</button></td>
</tr>

</table>
</form>
</body>
</html>
<script>document.form.name.focus();</script>
</form>
EOH
