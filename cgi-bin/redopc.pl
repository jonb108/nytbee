#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Terse = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;

CP:
for my $cp (<community_puzzles/*>) {
print "$cp\n";
    if ($cp eq 'community_puzzles/last_num.txt') {
        next CP;
    }
    open my $in, '<', $cp 
        or die "no $cp: $!\n";
    my ($name) = $cp =~ m{\A community_puzzles/(.*) \z}xms;
    open my $out, '>', "community_plus/$name"
        or die "no community_plus/$name: $!\n";
    my $line;
    {
        local $/;
        $line = <$in>;
    }
    my $href = eval $line;
    if ($@) {
        print "$cp oops $@\n";
        exit;
    }
    if (! $href) {
        print "$cp no href\n";
        next CP;
    }
    my @pangrams = @{$href->{pangrams}};
    my $nperfect = 0;
    for my $p (@pangrams) {
        if (length $p == 7) {
            ++$nperfect;
        }
    }
    $href->{npangrams} = @pangrams;
    $href->{nperfect} = $nperfect;

    my %is_pangram = map { $_ => 1 } @pangrams;

    my @words = @{$href->{words}};

    $href->{nwords} = @words;
    my $max_score = 0;
    my $gn4l_score = 0;
    my $gn4l_np_score = 0;
    my $nwords = @words;
    my %first_letter;
    for my $w (@words) {
        ++$first_letter{substr($w, 0, 1)};
        my $lw = length $w;
        if ($lw == 4) {
            $max_score += 1;
        }
        else {
            if ($is_pangram{$w}) {
                my $word_score = $lw + 7;
                $max_score += $word_score;
                $gn4l_score += $word_score;
            }
            else {
                $max_score += $lw;
                $gn4l_score += $lw;
                $gn4l_np_score += $lw;
            }
        }
    }
    $href->{bingo}   = keys %first_letter == 7? 1: 0;
    $href->{max_score} = $max_score;
    my $genius  = int(70*$max_score/100);
    $href->{gn4l}    = $gn4l_score    >= $genius? 1: 0;
    $href->{gn4l_np} = $gn4l_np_score >= $genius? 1: 0;

    print {$out} Dumper($href);
    close $in;
    close $out;
}
