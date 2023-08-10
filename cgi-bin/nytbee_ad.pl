#!/usr/bin/env perl
use strict;
use warnings;
use DB_File;
my %admin;
tie %admin, 'DB_File', 'admin.dbm';
my %screen_name_uuid;
tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';

# add or subtract an administrator
my $add = $ARGV[0] eq '+';
my $lsn = $ARGV[1];   # lower case screen name
my ($sn, $uuid);
my $screen_name;
SN:
while (($sn, $uuid) = each %screen_name_uuid) {
    if (lc $sn eq $lsn) {
        $screen_name = $sn;
        last SN;      
    }
}
if (! $screen_name) {
    print "\U$lsn\E: unknown screen name";
}
else {
    if (exists $admin{$screen_name}) {
        if (! $add) {
            delete $admin{$screen_name};
            print "$screen_name: removed";
        }
        else {
            print "$screen_name: already an administrator";
        }
    }
    else {
        if ($add) {
            $admin{$screen_name} = 1;
            print "$screen_name: added";
        }
        else {
            print "$screen_name: not an administator";
        }
    }
}
