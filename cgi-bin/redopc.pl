#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent = 1;

CP:
for my $cp (<community_puzzles/*>) {
#??
print "$cp\n";
<STDIN>;
    open my $in, '<', $cp 
        or die "no $cp: $!\n";
    my ($name) = $cp =~ m{\A community_puzzles/(.*) \z}xms;
    open my $out, '>', "community_plus/$name"
        or die "no community_plus/$name: $!\n";
    my $line = <$in>;
    my $href = eval $line;
    if (! $href) {
        # ??
        # unlink $cp;
        next CP;
    }

# ??
$Data::Dumper::Indent = 1;
print Dumper($href);
<STDIN>;
$Data::Dumper::Indent = 1;      # test then zero 0
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
    print Dumper($href);
    <STDIN>;
    # ??
    # $Data::Dumper::Indent = 1;      # test then zero 0
    #print {$out} Dumper($href);

=comment 

        my ($seven, $center, @pangrams) = split ' ', $t;
        my $npangrams = @pangrams;
        my %is_pangram = map { $_ => 1 } @pangrams;
        my $nperfect = 0;
        for my $p (@pangrams) {
            if (length $p == 7) {
                ++$nperfect;
            }
        }
        my @words = split ' ', $words;
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
        my $bingo = keys %first_letter == 7? 1: 0;
        my $genius = int(70*$max_score/100);
        my $gn4l    = $gn4l_score    >= $genius? 1: 0;
        my $gn4l_np = $gn4l_np_score >= $genius? 1: 0;
        #print "dt $date $seven $center npan $npangrams nperfect $nperfect nwords $nwords max $max_score bingo $bingo gn4l $gn4l gn4l_np $gn4l_np @pangrams | @words\n";
        print {$out} "$date => $seven $center $npangrams $nperfect $nwords $max_score $bingo $gn4l $gn4l_np @pangrams | @words\n";

=cut

    close $in;
    close $out;
}
