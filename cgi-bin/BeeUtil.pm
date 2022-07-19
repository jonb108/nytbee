use strict;
use warnings;
package BeeUtil;
use base 'Exporter';
our @EXPORT_OK = qw/
    ymd
    cgi_header
    uniq_chars
    uniq_words
    error
    word_score
    trim
    table
    Tr
    th
    td
    div
    ul
    bold
    slash_date
    shuffle
    JON
    red
    my_today
    $log
    $cgi
    $cgi_dir
    get_html
    $thumbs_up
/;

use Date::Simple qw/
    today
/;

our $log     = 'https://logicalpoetry.com';
our $cgi     = 'https://logicalpoetry.com/cgi-bin';
our $cgi_dir = '/home4/logical9/www/cgi-bin';
our $thumbs_up = '&#128077;';

#
# handle the creation and maintenance of the uuid
#
sub cgi_header {
    my ($q, $another_cookie) = @_;

    my $cmd = $q->param('new_words');
    my $uuid;
    if ($cmd && $cmd =~ m{\A id \s+ (\S+) \s* \z}xmsi) {
        $uuid = $1;
    }
    else {
        $uuid = $q->cookie('uuid');
    }
    if (! $uuid) {
        # only load this module if it is needed
        require UUID::Tiny;
        $uuid = UUID::Tiny::create_uuid_as_string(1);
    }
    my $uuid_cookie = $q->cookie(
        -name    => 'uuid',
        -value    => $uuid,
        -expires => '+20y',
    );
    if ($another_cookie) {
        print $q->header(-cookie => [ $uuid_cookie, $another_cookie ]);
    }
    else {
        print $q->header(-cookie => $uuid_cookie);
    }
    return $uuid;
}

sub my_today {
    my ($hour) = (localtime)[2];
    my $today = today();
    if ($hour < 1) {
        # the machine is in MST
        # and the "next day" doesn't start until 3:00 AM EST
        --$today;
    }
    return $today;
}

sub slash_date {
    my ($d8) = @_;
    if ($d8 =~ m{\A CP}xmsi) {
        return uc $d8;
    }
    my ($y, $m, $d) = $d8 =~ m{\A ..(..)(..)(..) \z}xms;
    return "$m/$d/$y";
}

sub uniq_chars {
    my ($word) = @_;
    my %seen;
    my @chars = sort grep { !$seen{$_}++; } split //, $word;
    return @chars;
}

sub uniq_words {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub error {
    my ($msg) = @_;
    print <<"EOH";
<style>
body {
    margin-top: .5in;
    margin-left: .5in;
    font-family: Arial;
    font-size: 18pt;
}
.back {
    font-size: 18pt;
    background: lightgreen;
}
</style>
$msg
<p>
Please <button class=back id=back onclick="history.go(-1)">Go Back</button> and fix this.
<script type='text/javascript'>document.getElementById('back').focus();</script>
EOH
    exit;
}

sub word_score {
    my ($word, $pangram) = @_;
    my $l = length $word;
    return ($l == 4? 1: $l) + ($pangram? 7: 0);
}

sub trim {
    my ($s) = @_;
    $s =~ s{\A \s* | \s* \z}{}xmsg;
    return $s;
}

sub _attrs {
    my $href = shift;
    return ' ' . join ' ',
           map { "$_='$href->{$_}'" }
           keys %$href;
}
sub table {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<table$attrs>@_</table>";
}
sub div {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<div$attrs>@_</div>";
}
sub Tr {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<tr$attrs>@_</tr>";
}
sub th {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<th$attrs>@_</th>";
}
sub td {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<td$attrs>@_</td>";
}
sub ul {
    return "<ul>@_</ul>";
}
sub bold {
    return "<b>@_</b>";
}

sub shuffle {
    my (@elems) = @_;
    my @new;
    push @new, splice @elems, rand @elems, 1 while @elems;
    return @new;
}

sub red {
    return "<span class=red1>@_</span>";
}

sub JON {
    open my $jon, '>>', '/tmp/jon';
    print {$jon} "@_\n";
    close $jon;
}

sub get_html {
    my ($url) = @_;
    require LWP::Simple;
    return LWP::Simple::get($url);
}

sub ymd {
    my $today = my_today();
    return $today->format("%Y-%m-%d");
}

1;
