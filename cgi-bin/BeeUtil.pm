use strict;
use warnings;
package BeeUtil;
use base 'Exporter';
our @EXPORT_OK = qw/
    uniq_chars
    error
    word_score
    trim
    ip_id
    table
    Tr
    td
    ul
    slash_date
    shuffle
/;

sub slash_date {
    my ($d8) = @_;
    if ($d8 =~ m{\A CP}xms) {
        return $d8;
    }
    my ($y, $m, $d) = $d8 =~ m{\A ..(..)(..)(..) \z}xms;
    return "$m/$d/$y";
}

sub ip_id {
    my $ua = $ENV{HTTP_USER_AGENT};
    $ua =~ s{\D}{}xmsg;
    return "$ENV{REMOTE_ADDR} $ua";
}

sub uniq_chars {
    my ($word) = @_;
    my %seen;
    my @chars = sort grep { !$seen{$_}++; } split //, $word;
    return @chars;
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
Please <button class=back id=back onclick="history.go(-1)">go back</button> and fix this.
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
    return join ',',
           map { "$_='$href->{$_}'" }
           keys %$href;
}
sub Tr {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<tr $attrs>@_</tr>";
}
sub td {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<td $attrs>@_</td>";
}
sub ul {
    return "<ul>@_</ul>";
}
sub table {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<table $attrs>@_</table>";
}

sub shuffle {
    my (@elems) = @_;
    my @new;
    push @new, splice @elems, rand @elems, 1 while @elems;
    return @new;
}


1;
