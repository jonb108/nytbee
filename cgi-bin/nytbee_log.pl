#!/usr/bin/env perl
use strict;
use warnings;
use BeeUtil qw/
    my_today
/;
print <<'EOH';
<style>
.lg {
    color: #009900;
}
</style>
EOH
my ($date, $uuid11) = @ARGV;
open my $in, '<', "beelog/$date";
my $saved_time = '';
LINE:
while (my $line = <$in>) {
    chomp $line;
    if (index($line, "$uuid11 = ") >= 0 && index($line, " = *") == -1) {
        if ($saved_time) {
            print "<span class=gray>$saved_time</span><br>\n";
            $saved_time = '';
        }
        $line =~ s{\A .* = }{}xms;
        $line =~ s{(\w+)}{length($1) < 4? "<span class=lg>\U$1\E</span>": ucfirst $1}xmsge;
        print "$line<br>\n";
    }
    if ($line =~ m{\A (\d\d):(\d)\d}xms) {
        $saved_time = $line;
    }
}
close $in;
