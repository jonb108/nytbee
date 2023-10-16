#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my %who_played;
tie %who_played, 'DB_File', 'who_played.dbm';
use Date::Simple qw/
    date
    today
/;
my $today = today();
my $start = date(2023, 1, 1);

my @base = qw/
    Bee
    Drone
    Queen
    Hive
    Worker
    Bumble
    Honey
    Apian
    Buzz
/;
my $base = '(' . join('|', @base) . ')';

sub who_played_on {
    my ($d) = @_;
    for my $p (split ' ', $who_played{$d}) {
        if ($p !~ m{\A $base\d+ \z}xms) {
            print "$p<br>\n";
        }
    }
}

my $arg = shift;
my $my_screen_name = shift;
if ($arg =~ m{\A \d+ \z}xms) {
    my %times_played;
    LOOP:
    for my $i (1 .. $arg) {
        my $d = $today - $i + 1;
        if ($d < $start) {
            last LOOP;
        }
        for my $p (split ' ', $who_played{$d->as_d8()}) {
            if ($p !~ m{\A $base\d+ \z}xms) {
                ++$times_played{$p};
            }
        }
    }
    my $asc = int(rand(2));
    PERSON:
    for my $p (sort {
                   $times_played{$b} <=> $times_played{$a}
                   ||
                   ($asc? $a cmp $b
                   :      $b cmp $a)
               }
               keys %times_played
    ) {
        my $star = $p eq $my_screen_name? '<span class=red> *</span>': '';
        print "$p $times_played{$p}$star<br>\n";
    }
}
elsif (my ($mon, $day) = $arg =~ m{\A (\d+)/(\d+) \z}xms) {
    my $d = date($today->year, $mon, $day);
    who_played_on($d->as_d8());
}
elsif ($arg =~ m{\A (\d+)/(\d+)/(\d+) \z}xms) {
    my $d = date($arg);
    if (! $d) {
        print "Invalid date: $arg\n";
    }
    elsif ($d < $start) {
        print "Date is before 1/1/2023\n";
    }
    else {
        who_played_on($d->as_d8());
    }
}
