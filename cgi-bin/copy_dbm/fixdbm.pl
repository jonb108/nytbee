#!/usr/bin/env perl
use strict;
use warnings;

# These dbm files all use the uuid.
#    %cur_puzzles_store
#    %end_time_for
#    %full_uuid
#    %uuid_screen_name
#    %screen_name_uuid
#    %settings_for
#    %uuid_colors_for
#    %uuid_color_schemes_for
#
use File::Copy qw/
    copy
/;

mkdir 'orig';
for my $name (qw/
    cur_puzzles_store
    end_time_for
    full_uuid
    uuid_screen_name
    screen_name_uuid
    settings_for
    uuid_colors_for
    uuid_color_schemes_for
/) {
    copy("../$name.dbm", 'orig');
}
use DB_File;
use lib '..';

use Date::Simple qw/
    today
/;
my $dt30 = today() - 30;
my $dt60 = today() - 60;
#print "date30 = ", $dt30->as_d8(), "\n";
#print "date60 = ", $dt60->as_d8(), "\n";

sub gen_id {
    my ($id) = @_;
    # e3123acd-802b-11ef-b9f9-aaec35dca667
    my @parts = split '-', $id;
    return @parts == 5;
}

my $ok = 0;
my $purged = 0;
my $cleared = 0;
copy('../cur_puzzles_store.dbm', '.');
my %cur;
tie %cur, 'DB_File', 'cur_puzzles_store.dbm';
while (my ($k, $v) = each %cur) {
    my %puzz = %{ eval $v };
    my @dates = sort grep { ! m{\A CP }xms } keys %puzz;
    my $n = @dates;
    #print "$k => $n";
    if ($n) {
        #print " $dates[0] .. $dates[-1]";
    }
    #print "\n";
    my $gid = gen_id($k);
    #
    # either no games at all or
    #     they have not set an ID
    #     and the last game played was more than 30 days ago
    #   delete the entry
    # or if they have set an ID
    #     but the last game played was more than 60 days ago
    #   clear the games out
    # otherwise leave it alone
    #
    #
    # if someone does not clear their cookies and does not
    # set an ID and still they play every day their games
    # will not be cleared.  They will be reminded every day
    # to set an ID as long as they have at least 3 games they
    # have not cleared out.
    #
    if (!$n || ($gid && $dates[-1] < $dt30)) {
        #print "PURGE IT\n";
        delete $cur{$k};
        ++$purged;
    }
    elsif (!$gid && $dates[-1] < $dt60) {
        #print "CLEAR IT\n";
        $cur{$k} = "{}";
        ++$cleared;
    }
    else {
        #print "OK\n";
        ++$ok;
    }
    #<STDIN>;
}
#print "ok = $ok\n";
#print "purged = $purged\n";
#print "cleared = $cleared\n";

# we have trimmed down cur_...
# at this point %cur still has upper case keys
# that are the full uuid.
#
# the screen names are here:
my %orig_uuid_screen_name;
tie %orig_uuid_screen_name, 'DB_File', 'orig/uuid_screen_name.dbm';
# with uuid11 (possibly upper case)
#
# and the settings are here:
my %orig_settings_for;
tie %orig_settings_for, 'DB_File', 'orig/settings_for.dbm';
# with uuid11 (possibly upper case)
#
# and the colors and color schemes are here:
my %orig_uuid_colors_for;
tie %orig_uuid_colors_for, 'DB_File', 'orig/uuid_colors_for.dbm';
my %orig_uuid_color_schemes_for;
tie %orig_uuid_color_schemes_for, 'DB_File', 'orig/uuid_color_schemes_for.dbm';
# with uuid11 (possibly upper case)

# these we recreate rather than copy
unlink qw/
    full_uuid.dbm
    uuid_screen_name.dbm
    screen_name_uuid.dbm
    settings_for.dbm
    uuid_colors_for.dbm
    uuid_color_schemes_for.dbm
/;
my %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
my %screen_name_uuid;
tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';
my %settings_for;
tie %settings_for, 'DB_File', 'settings_for.dbm';
my %uuid_colors_for;
tie %uuid_colors_for, 'DB_File', 'uuid_colors_for.dbm';
my %uuid_color_schemes_for;
tie %uuid_color_schemes_for, 'DB_File', 'uuid_color_schemes_for.dbm';
while (my ($uk, $v) = each %cur) {
    my $uk11 = substr($uk, 0, 11);
    my $k = lc $uk;
    my $k11 = substr($k, 0, 11);
    $full_uuid{ $k11 } = $k;
    my $sn = $orig_uuid_screen_name{$uk11};
    if ($sn) {
        $uuid_screen_name{ $k11 } = $sn;
        $screen_name_uuid{ $sn } = $k11;
    }
    my $os = $orig_settings_for{$uk};
    if ($os) {
        # 0 0 0 => 0 0 0 0
        if (length($os) == 5) {
            $os = $os . ' 0';
        }
        $settings_for{ $k } = $os;
    }
    my $cf = $orig_uuid_colors_for{$uk};
    if ($cf) {
        $uuid_colors_for{ $k } = $cf;
    }
    my $csf = $orig_uuid_color_schemes_for{$uk};
    if ($csf) {
        $uuid_color_schemes_for{ $k } = $csf;
    }
}
# the preset colors
for my $char ('a' .. 'g') {
    my $key = "preset $char";
    $uuid_colors_for{$key} = $orig_uuid_colors_for{$key};
}
# NOW we can do the lowercasing of the cur_puzzles_store dbm file.
while (my ($uk, $v) = each %cur) {
    if ($uk =~ m{[A-Z]}xms) {
        delete $cur{$uk};
        $cur{lc $uk} = $v;
    }
}

sub fix_key {
    my ($name) = @_;
    copy("../$name.dbm", '.');
    my %hash;
    tie %hash, 'DB_File', "$name.dbm";
    while (my ($k, $v) = each %hash) {
        if (exists $full_uuid{lc $k}) {
            if ($k =~ m{[A-Z]}xms) {
                $hash{lc $k} = $v;
                delete $hash{$k};
            }
        }
        else {
            #print "no $k in full_uuid\n";
            delete $hash{$k};
        }
    }
    untie %hash;
}

fix_key('end_time_for');    # the only one...
