#!/usr/bin/env perl
use warnings;
use strict;
use BeeUtil qw/
    slash_date
    table
    Tr
    td
/;
my ($seven, $cur_date, @cur_words) = @ARGV;
my $n_cur_words = @cur_words;
my %cur_words = map { $_ => 1 } @cur_words;
my @lines = `grep "=> $seven" nyt_puzzles.txt`;
my @rows;
my $sp = '&nbsp;' x 2;
for my $l (@lines) {
    my ($date, $center, $words) = $l =~ m{
        \A
           (\d{8})      # date
           [ ] => [ ]   #  => 
           .{7} [ ] (.) # center
           .* [|] (.*)  # | words
        \z
    }xms;
    if ($date ne $cur_date) {
        $center = uc $center;
        my $n = 0;
        for my $w (split ' ', $words) {
            if (exists $cur_words{$w}) {
                ++$n;
            }
        }
        push @rows,
            Tr(
                td(qq!<span class=alink onclick="issue_cmd('$date');">!
                   . slash_date($date) . '</span>'),
                td($sp . uc $center),
                td({ align => 'right'},
                   $sp . int(100 * ($n/$n_cur_words)) . '%'),
            );
    }
}
my @fnames = `grep -l "'seven' => '$seven'" community_puzzles/*`;
chomp @fnames;
for my $f (@fnames) {
    my $cp_href = do $f;
    my ($cpn) = $f =~ m{(\d+)}xms;
    my @words = @{ $cp_href->{words} };
    my $n = 0;
    for my $w (@words) {
        if (exists $cur_words{$w}) {
            ++$n;
        }
    }
    push @rows, Tr(
                    td(qq!<span class=alink onclick="issue_cmd('CP$cpn');">!
                       . "CP$cpn". '</span>'),
                    td(uc $cp_href->{center}),
                    td({ align => 'right'},
                       $sp . int(100 * ($n/$n_cur_words)) . '%'),
                );
}
print table(@rows);
