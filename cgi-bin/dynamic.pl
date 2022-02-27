#!/usr/bin/perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
use BeeUtil qw/
    cgi_header
    table
    Tr
    td
    th
    my_today
    $cgi
    word_score
/;
use DB_File;
my $uuid = cgi_header($q);
open my $out, '>>', 'cmd_log.txt';
print {$out} substr($uuid, 0, 5) . " dynamic tables\n";
close $out;
#
# save the uuid and the ip address 
# so we can know where people are playing from
#
my %uuid_ip;
tie %uuid_ip, 'DB_File', 'uuid_ip.dbm';
$uuid_ip{$uuid} = $ENV{REMOTE_ADDR} . '|' . $ENV{HTTP_USER_AGENT};

my $pwords = $q->param('words') || '';
$pwords =~ s{\A \s*|\s* \z}{}xmsg;
$pwords =~ s{"}{}xmsg;
$pwords =~ s{\A .*You\s+have\s+found\s+\d*\s+words}{}xms;
$pwords =~ s{Type\s+or\s+click.*\z}{}xms;

my $words = $pwords;
$words =~ s{[^a-z ]}{}xmsgi;
my ($hint_table, $two_lets) = ('', '');
my $today = my_today();
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';
my ($s, $t) = split /[|]/, $puzzle{ $today->as_d8() };
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
# extract, validate, lower case, and unduplicate
my %is_found = map { $_ => 1 }
               grep { $is_ok_word{$_} }
               map { lc }
               $words =~ m{([a-z]+)}xmsgi;
my @words = keys %is_found;
$pwords = join ' ',
          map { ucfirst }
          sort
          @words;
$pwords .= ' ' if $pwords;
my $nwords = @words;
my $pl_w = $nwords == 1? '': 's';
my $score = 0;
for my $w (@words) {
    $score += word_score($w, $is_pangram{$w});
}
my $rank = '';
RANK:
for my $r (reverse @ranks) {
    if ($score >= $r->{value}) {
        $rank = $r->{name};
        last RANK;
    }
}
my $pl_sc = $score == 1? '': 's';
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
    push @cells, th({ class => 'lt' }, uc $c);
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
    push @th, th({ class => 'rt' }, $sums{1}{1} || 0);
    push @rows, Tr(@th);
}
$hint_table = table({ cellpadding => 2 }, @rows);

# two letter tallies
$two_lets = '';
my @two = grep {
              $two_lets{$_}
          }
          sort
          keys %two_lets;
TWO:
for my $i (0 .. $#two) {
    if ($two_lets{$two[$i]} == 0) {
        next TWO;
    }
    $two_lets .= "\U$two[$i]\E-$two_lets{$two[$i]}";
    if ($i < $#two
        && substr($two[$i], 0, 1) ne substr($two[$i+1], 0, 1)
    ) {
        $two_lets .= "<p>";
    }
    else {
        $two_lets .= '&nbsp;&nbsp;';
    }
}
print <<"EOH";
<html>
<head>
<style>
body, td, th, input {
    margin-top: .3in;
    margin-left: .3in;
    font-family: Arial;
    font-size: 18pt;
}
form {
    margin-top: 0mm;
    margin-bottom: 0mm;
}
input {
    margin-top: 0mm;
    margin-left: 0mm;
}
.rt {
    text-align: right;
}
.lt {
    text-align: left;
}
.float1 {
    float: left;
    margin-left: 0mm;
}
.float2 {
    float: left;
    margin-top: 0mm;
    margin-left: 6mm;
    line-height: 9mm;
}
.help {
    margin-left: .5in;
    color: blue;
    cursor: pointer;
}
.date {
    margin-right: .5in;
}
p {
    margin-top: 3mm;
    margin-bottom: 3mm;
}
</style>
</head>
<script>
function set_focus() {
    document.form.words.focus();
}
function help_win() {
    window.open('https://logicalpoetry.com/nytbee/dyn_help.html', 'help',
                'popup=1, width=400, height=470, left=700');
}
</script>
<body>
EOH
print "<span class=date>" . $today->format("%B %e, %Y") . "</span>";
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
<input type=text name=words size=45 value="$pwords">
<p>
</form>$nwords word$pl_w, $score point$pl_sc, $rank
<p>
<div class=float1>$hint_table</div>
<div class=float2>$two_lets</div>
</body>
</html>
<script>set_focus();</script>
EOH
