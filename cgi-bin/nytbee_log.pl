#!/usr/bin/env perl
use strict;
use warnings;
use BeeUtil qw/
    my_today
/;
my @rank = map { my $x = $_; $x =~ s/_/ /; $x; } qw/
    Beginner
    Good_Start
    Moving_Up
    Good
    Solid
    Nice
    Great
    Amazing
    Genius
    Queen_Bee
/;
print <<'EOH';
<style>
.lg {
    color: #009900;
}
</style>
EOH
my ($date, $uuid11);
if ($ARGV[0] eq '-s') {
    shift;
    my $sn;
    ($date, $sn) = @ARGV;
    my %uuid_screen_name;
    tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
    open my $in, '<', "beelog/$date";
    my %sn_for;
    LINE:
    while (my $line = <$in>) {
        chomp $line;
        if (my ($uid) = $line =~ m{\A (\S+) \s+ =}xms) {
            if (! exists $sn_for{$uid}) {
                $sn_for{$uid} = $uuid_screen_name{$uid};
            }
        }
    }
    close $in;
    for my $uid (keys %sn_for) {
        if ($sn_for{$uid} =~ m{\A $sn \z}xmsi) {
            $uuid11 = $uid;
            last;
        }
    }
    if (! $uuid11) {
        print "$sn: Unknown screen name<br>\n";
        exit;
    }
}
else {
    ($date, $uuid11) = @ARGV;
}
open my $in, '<', "beelog/$date"
    or die "wrong date: $date\n";
my $saved_time = '';
LINE:
while (my $line = <$in>) {
    chomp $line;
    if (index($line, "$uuid11 = ") >= 0 && index($line, " = *") == -1) {
        if ($saved_time) {
            print "<span class=gray>$saved_time</span><br>\n";
            $saved_time = '';
        }
        $line =~ s{\A .* = \s+}{}xms;
        if ($line =~ m{\A rank(\d)}xmsi) {
            my $r = $1;
            $line =~ s{rank\d \s+ \S+}{}xms;
                # leaving GN4L or GOTN
            $line = "<span class=lg>Rank $rank[$r]$line</span>";
        }
        else {
            $line =~ s{(\w+)}
                      {
                        length($1) < 4? "<span class=lg>\U$1\E</span>"
                       :                ucfirst $1
                      }xmsge;
        }
        print "$line<br>\n";
    }
    if ($line =~ m{\A (\d\d):(\d)\d}xms) {
        $saved_time = $line;
    }
}
close $in;
