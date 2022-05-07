#!/usr/bin/perl
use strict;
use warnings;
use File::Copy qw/
    copy
/;
use File::Slurp qw/
    read_file
    write_file
/;
system("rm -f ../nytbee/list/*");
for my $s (qw/ date center score four nwords npangrams bingo /) {
    system("./nytbee_list.pl puzzle $s asc");
    system("./nytbee_list.pl puzzle $s desc");
}
for my $s (qw/ word first freq length /) {
    system("./nytbee_list.pl word $s asc");
    system("./nytbee_list.pl word $s desc");
}
chdir '../nytbee/list';
for my $f (<*>) {
    my $g = $f;
    $g =~ s{.html}{-full.html}xms;
    copy($f, $g);
    trunc($f, $g);
}
copy '../../cgi-bin/nyt_puzzles.txt', '.';

sub trunc {
    my ($f, $g) = @_;
    my $load = <<"EOH";
<tr>
<td colspan=10 align=center><p><a href=$g>Load the entire file.</a></td>
</tr>
EOH
    my @lines = read_file($f);
    splice(@lines, 58, -3, $load);
    write_file($f, @lines);
}
