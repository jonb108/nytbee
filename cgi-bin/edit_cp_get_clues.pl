#!/usr/bin/perl
use strict;
use warnings;

use CGI;
use CGI::Carp qw/
    warningsToBrowser
    fatalsToBrowser
/;
use Bee_DBH qw/
    $dbh
/;
use BeeUtil qw/
    my_today
    $log
/;

my $q = CGI->new();
print $q->header();

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

#
# save any word and clues changes now
# even though we go on to ask for any changes 
# in the name, location, title, description and publish.
#
use Data::Dumper;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;
open my $out, '>', $fname;
print {$out} Dumper($href);
close $out;

my $publish_checked = $href->{publish} eq 'yes'? 'checked': '';


print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
<script src="$log/nytbee/js/nytbee4.js"></script>
</head>
<body>
<h1>Editing $date <span class=step_name>Info</span></h1>
<form name=form action=$log/cgi-bin/edit_cp_final.pl method=POST onsubmit="return check_name_location();">
<input type=hidden name=CPn value="$CPn">
<div style="width: 650px">
Update information about yourself,
the title, and description.
</div>
<p>
<table cellpadding=5>

<tr>
<th>Name</th>
<td class=left><input type=text name=name id=name value="$href->{name}" size=40></td>
</tr>

<tr>
<th>Location</th>
<td class=left><input type=text name=location id=location value="$href->{location}" size=40></td>
</tr>

<tr>
<th>Title</th>
<td class=left><input type=text name=title id=title value="$href->{title}" size=40></td>
</tr>

<tr>
<th valign=top>Description</th>
<td class=left><textarea name=description id=description rows=5 cols=32>$href->{description}</textarea></td>
</tr>

<tr>
<th>Ready to<br>Publish?</th>
<td class=left valign=center><input type=checkbox name=publish id=publish value=yes $publish_checked></td>
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
