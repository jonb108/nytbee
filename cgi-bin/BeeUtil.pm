use strict;
use warnings;
package BeeUtil;
use base 'Exporter';
our @EXPORT_OK = qw/
    uniq_chars
    error
    word_score
/;

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


1;
