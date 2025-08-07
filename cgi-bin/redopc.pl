#!/usr/bin/env perl
use strict;
use warnings;
use BeeUtil qw/
    puzzle_info
/;
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
    # an lvalue of a hash slice!
    @$href{qw/
        nwords max_score
        npangrams nperfect
        bingo gn4l gn4l_np
    /} = puzzle_info($href->{words}, $href->{pangrams});

    print {$out} Dumper($href);
    close $in;
    close $out;
}
