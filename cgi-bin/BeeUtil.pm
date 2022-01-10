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
    display_clues
/;


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

sub display_clues {
    my ($date, $name, $clue_for_href, $was_found_href) = @_;
    print <<"EOH";
<html>
<head>
<style>
body {
    margin: .5in;
    font-family: Arial;
    font-size: 18pt;
}
</style>
<body>
<h3>Hints for $date by $name</h3>
EOH
    my $prev_l2 = '';
    for my $w (sort keys %$clue_for_href) {
        my $lw = length($w);
        my $l2 = substr($w, 0, 2);
        if ($prev_l2 ne $l2) {
            print "<p>\U$l2\E<br>\n";
        }
        print ucfirst($clue_for_href->{$w}) . " - $lw";
        if ($was_found_href->{$w}) {
            print " = \U$w";
        }
        print "<br>\n";
        $prev_l2 = $l2;
    }
    print <<'EOH';
</body>
</html>
EOH
}

1;
