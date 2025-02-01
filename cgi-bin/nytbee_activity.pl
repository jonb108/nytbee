#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;
use BeeUtil qw/
    ymd
/;
use List::Util qw/
    max
/;
my ($date, $text_color) = @ARGV;
open my $in, '<', "beelog/$date";
my (@words, @grid, @cmds);
my $i;
LINE:
while (my $line = <$in>) {
    chomp $line;
    if ($line =~ m{\A (\d\d):(\d)\d}xms) {
        $i = $1*6 + $2;
        next LINE;
    }
    if ($line =~ m{new[ ]puzzle
                  |dyntab[ ]suggestion
                  |mkclues
                  |making.*puzzle
                  |getting[ ]clues
                  |creating[ ]CP
                  |asking[ ]for[ ]clues
                  |edited[ ]CP
                 }xms
    ) {
        next LINE;
    }
    if (index($line, ' = rank') >= 0 && $line =~ m{rank\d}) {
        next LINE;
    }
    if (index($line, ' = ') >= 0) {
        if ($line =~ m{[a-z]{4,}}xms) {
            ++$words[$i];
        }
        else {
            ++$cmds[$i];
        }
    }
    elsif (index($line, 'dyntab:') >= 0) {
        ++$grid[$i];
    }
    else {
        say "UNKNOWN: $line";
    }
}
close $in;
my $max = max(scalar(@words), scalar(@grid), scalar(@cmds));
my $h = 0;
my $plot_w = 8;
my $stretch = 1.2;
my $bottom = 20;
for my $i (0 .. $max-1) {
    my $x = $words[$i] + $cmds[$i] + $grid[$i];
    if ($x > $h) {
        $h = $x;
    }
}
my $width = $max*$plot_w + 40;   # plus for the first 10 minutes of the hour
my $height = $h*$stretch + $bottom;
print <<"EOH";
<svg width=$width height=$height>
EOH
for my $i (0 .. $max-1) {

    # the hour
    if ($i % 6 == 0) {
        my $h = $i / 6; 
        if ($h > 12) {
            $h -= 12;
        }
        print "<text x="
                   . ($i*$plot_w)
                   . " y="
                   . ($height-$bottom+20)
                   . " fill=$text_color"
                   . ">$h</text>\n";
    }

    # words
    my $rect = '<rect';
    my $v = $words[$i] || 0;
    $rect .= ' x=' . $i*$plot_w;
    $rect .= " width=$plot_w";
    my $top = ($height-($v*$stretch) - $bottom);
    $rect .= " y=$top";
    $rect .= " height=" . ($v*$stretch);
    $rect .= " fill=green";
    $rect .= " />";
    print "$rect\n";

    # commands
    $rect = '<rect';
    $v = $cmds[$i] || 0;
    $rect .= ' x=' . $i*$plot_w;
    $rect .= " width=$plot_w";
    my $top2 = $top - ($v*$stretch);
    $rect .= " y=$top2";
    $rect .= " height=" . ($v*$stretch);
    $rect .= " fill=red";
    $rect .= " />";
    print "$rect\n";

    # grid
    $rect = '<rect';
    $v = $grid[$i] || 0;
    $rect .= ' x=' . $i*$plot_w;
    $rect .= " width=$plot_w";
    my $top3 = $top2 - ($v*$stretch);
    $rect .= " y=$top3";
    $rect .= " height=" . ($v*$stretch);
    $rect .= " fill=blue";
    $rect .= " />";
    print "$rect\n";
}
