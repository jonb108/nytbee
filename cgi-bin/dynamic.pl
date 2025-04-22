#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use CGI::Carp qw/
    warningsToBrowser
    fatalsToBrowser
/;
use BeeUtil qw/
    ymd
    cgi_header
    my_today
    $cgi
    word_score
    $log
/;
use BeeHTML qw/
    table
    Tr
    td
    th
/;
use DB_File;
use DB_File::Lock;
use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

my $q = CGI->new();
my $uuid = cgi_header($q);
#
# save the uuid and the ip address 
# so we can know where people are playing from
#
my %uuid_ip;
tie %uuid_ip, 'DB_File', 'uuid_ip.dbm';
$uuid_ip{$uuid} = $ENV{REMOTE_ADDR} . '|' . $ENV{HTTP_USER_AGENT};

# how often has this person entered a single word?
my %uuid_single;
tie %uuid_single, 'DB_File', 'uuid_single.dbm';

my ($hint_table, $two_lets) = ('', '');
my $today = my_today();
my $today_d8 = $today->as_d8();
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';
my ($s, $t) = split /[|]/, $puzzle{ $today_d8 };
my ($seven, $center, @pangrams) = split ' ', $s;
my @seven = split //, $seven;
my @ok_words = split ' ', $t;
my %is_pangram = map { $_ => 1 }
                 @pangrams;
my %is_ok_word = map { $_ => 1 }
                 @ok_words;
my $max_score = 0;
for my $w (@ok_words) {
    $max_score += word_score($w, $is_pangram{$w});
}
my @ranks = (
    { name => 'Beginner',   pct =>   0, value => 0 },
    { name => 'Good Start', pct =>   2, value => int(.02*$max_score + 0.5) },
    { name => 'Moving Up',  pct =>   5, value => int(.05*$max_score + 0.5) },
    { name => 'Good',       pct =>   9, value => int(.08*$max_score + 0.5) },
    { name => 'Solid',      pct =>  15, value => int(.15*$max_score + 0.5) },
    { name => 'Nice',       pct =>  25, value => int(.25*$max_score + 0.5) },
    { name => 'Great',      pct =>  40, value => int(.40*$max_score + 0.5) },
    { name => 'Amazing',    pct =>  50, value => int(.50*$max_score + 0.5) },
    { name => 'Genius',     pct =>  70, value => int(.70*$max_score + 0.5) },
    { name => 'Queen Bee',  pct => 100, value => $max_score },
);

# prior words
my $prior = $q->param('prior_words');
my %is_found = map { $_ => 1 }
               split ' ', $prior;

# more words that were pasted in/entered just now
# get, tidy, lower case, extract, validate, and unduplicate
my $words = lc $q->param('words') || '';
$words =~ s{\A .*uou\s+have\s+found\s+\d*\s+words}{}xms;
$words =~ s{type\s+or\s+click.* \z}{}xms;
$words =~ s{[^a-z ]}{}xmsg;        # strip stray characters

for my $w (grep { $is_ok_word{$_} } 
           $words =~ m{([a-z]+)}xmsgi
) {
    $is_found{$w} = 1;
}
my @words = sort keys %is_found;
my @uwords;
my $n_pangrams_found = 0;
for my $w (@words) {
    my $uw = ucfirst $w;
    if ($is_pangram{$w}) {
        ++$n_pangrams_found;
        my $color = length $w == 7? 'purple': 'green';
        push @uwords, "<span style='color: $color'>$uw</span>";
    }
    else {
        push @uwords, $uw;
    }
}
my $nwords = @words;
my $placeholder = $nwords? 'Paste or or enter more words here'
                 :         'Paste words here and hit Return';
my $pl_w = $nwords == 1? '': 's';
my $score = 0;
for my $w (@words) {
    $score += word_score($w, $is_pangram{$w});
}
my $pl_sc = $score == 1? '': 's';
my $rank = '';
my $rank_index = 9;
RANK:
for my $r (reverse @ranks) {
    if ($score >= $r->{value}) {
        $rank = $r->{name};
        last RANK;
    }
    --$rank_index;
}
my $suggest = '';
my $new_form = '';
# a single word?
if ($words =~ m{\A \s* [a-z]+ \s* \z}xms) {
    ++$uuid_single{$uuid};
    if ($uuid_single{$uuid} % 5 == 0) {
        $suggest = <<'EOH'
<div class=suggest>
You are entering single words instead of
select/copy/pasting words from the NYT app.
There's another place to play the game that you may find interesting:<p>
<ul>
    <span class=link onclick='play();'>https://UltraBee.org</span>
</ul>
<p>
This place <i>also</i> has a dynamic grid in addition to many
other ways to get hints.  Click on the link above and
give it a try!   There is a Help file that explains how it works.
</div>
EOH
    }
    # update the person's data to have the words found
    # and HT and TL already entered
    my %cur_puzzles_store;
    tie %cur_puzzles_store, 'DB_File::Lock', 'cur_puzzles_store.dbm',
                            O_CREAT|O_RDWR, 0666, $DB_HASH, 'write';
    my %cur_puzzles;
    my $s = $cur_puzzles_store{$uuid};
    if ($s) {
        %cur_puzzles = %{ eval $s };
    }
    my $all_pg = (@pangrams == $n_pangrams_found)? 1: 0;
    $cur_puzzles{$today_d8} = "15 $all_pg 1 1 $rank_index $score @words";
    $cur_puzzles_store{$uuid} = Dumper(\%cur_puzzles);
    untie %cur_puzzles_store;
    $new_form = <<"EOH";
<form id=nytbee
      target=_blank
      action='https://ultrabee.org/cgi-bin/nytbee.pl'
      method=POST
>
<input type=hidden name=date value='$today_d8'>
<input type=hidden name=has_message value=0>
<input type=hidden name=hive value=1>
<input type=hidden name=show_ZeroRowCol value=0>
</form>
EOH
}

open my $out, '>>', 'beelog/' . ymd();
print {$out} substr($uuid, 0, 11) . " dyntab: $words\n";
if ($suggest) {
    print {$out} substr($uuid, 0, 11) . " dyntab suggestion\n";
}
close $out;

my $input = "<input type=text name=words size=45"
          . " placeholder='$placeholder'>";
if ($rank eq 'Queen Bee') {
    $rank = "<span class=twolet>$rank</span>";
    $input = '';
}

# prepare the hint table and two letter list
my %sums;
my %two_lets;
my $max_len = 0;
my %first_char;
WORD:
for my $w (@ok_words) {
    if ($is_found{$w}) {
        # skip it
        next WORD;
    }
    my $l = length($w);
    if ($max_len < $l) {
        $max_len = $l;
    }
    my $c1 = substr($w, 0, 1);
    ++$first_char{$c1};
    my $c2 = substr($w, 0, 2);
    ++$sums{$c1}{$l};

    # the summations:
    ++$sums{$c1}{1};
    ++$sums{1}{$l};
    ++$sums{1}{1};

    # and the two letter list
    ++$two_lets{$c2};
}

# how many Non-zero columns and rows?
my $ncols = 0;
for my $l (4 .. $max_len) {
    if ($sums{1}{$l} != 0) {
        ++$ncols;
    }
}
my $nrows = 0;
for my $c (@seven) {
    if ($sums{$c}{1} != 0) {
        ++$nrows;
    }
}
# the hint tables
$hint_table = '';
my $space = '&nbsp;' x 4;
my @rows;
my @th;
my $dash = '&nbsp;-&nbsp;';
push @th, th('&nbsp;');
LEN:
for my $l (4 .. $max_len) {
    if ($sums{1}{$l} == 0) {
        next LEN;
    }
    push @th, th("$space$l");
}
if ($ncols > 1) {
    push @th, th("$space&nbsp;&Sigma;");
}
push @rows, Tr(@th);
CHAR:
for my $c (@seven) {
    if ($sums{$c}{1} == 0) {
        next CHAR;
    }
    my @cells;
    push @cells, th({ class => 'lt' },
                    "<span class=let>\U$c\E</span>");
    LEN:
    for my $l (4 .. $max_len) {
        if ($sums{1}{$l} == 0) {
            next LEN;
        }
        push @cells, td({ class => 'rt'},
                        $sums{$c}{$l}?  $sums{$c}{$l}: $dash);
    }
    if ($sums{$c}{1} != 0 && $ncols > 1) {
        push @cells, th({ class => 'rt' }, $sums{$c}{1} || 0);
    }
    push @cells, td({ width => 25 }, '&nbsp;');
    # the two letter tallies
    my $two_lets;
    for my $tl (grep { /^$c/ } sort keys %two_lets) {
        $two_lets .= "<span class='twolet'>\U$tl\E</span><span class=dash>-</span>$two_lets{$tl} ";
    }
    push @cells, td($two_lets);
    push @rows, Tr(@cells);
}
if ($nrows > 1) {
    @th = th({ class => 'rt' }, '&Sigma;');
    LEN:
    for my $l (4 .. $max_len) {
        if ($sums{1}{$l} == 0) {
            next LEN;
        }
        push @th, th({ class => 'rt' }, $sums{1}{$l} || $dash);
    }
    if ($ncols > 1) {
        push @th, th({ class => 'rt' }, $sums{1}{1} || 0);
    }
    push @rows, Tr(@th);
}
if ($nrows > 0) {
    $hint_table = table({ cellpadding => 2 }, @rows);
}
print <<"EOH";
<html>
<head>
<link rel='stylesheet' type='text/css' href='$log/css/dyn_style.css'/>
</head>
<script>
function set_focus() {
    document.form.words.focus();
}
function help_win() {
    window.open('https://ultrabee.org/dyn_help.html', 'help',
                'popup=1, width=400, height=470, left=700');
}
function play() {
    var f = document.getElementById('nytbee');
    f.submit();
}
</script>
<body>
EOH
for my $c (@seven) {
    my $C = uc $c;
    if ($c eq $center) {
        print "<span style='color: red'>$C</span> ";
    }
    else {
        print "$C ";
    }
}
print qq!<span class=help onclick="help_win(); set_focus();">Help</span>\n!;
print <<"EOH";
<p>
<form action=$cgi/dynamic.pl name=form method=post style="margin-bottom: 0mm">
$input
<input type=hidden name=prior_words value="@words">
</form>
<p>
$suggest
<p>
$nwords word$pl_w, $score point$pl_sc, $rank
<p>
$hint_table
<div class=words>
@uwords
</div>
$new_form
</body>
</html>
<script>set_focus();</script>
EOH
