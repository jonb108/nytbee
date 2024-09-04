#!/usr/bin/env perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
use DB_File;
my %uuid_screen_name;
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';

my $existing_id = $q->param('existing_id');
if (! exists $uuid_screen_name{$existing_id}) {
    print $q->header();
    print "$existing_id: That identity string was not found. :(\n";
    exit;
}
my $the_id;
if ($existing_id) {
    $the_id = $existing_id;
}
else {
    my $uuid = $q->param('new_id');
    my $screen_name = $q->param('new_sn');

    # check new_id and new_sn

    my $uuid11 = substr($uuid, 0, 11);

    my %screen_name_uuid;
    tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';
    my %full_uuid;
    tie %full_uuid, 'DB_File', 'full_uuid.dbm';
    $full_uuid{$uuid11} = $uuid;
    $screen_name_uuid{$screen_name} = $uuid11;
    $uuid_screen_name{$uuid11} = $screen_name;
    $the_id = $uuid;
}
my $uuid_cookie = $q->cookie(
    -name    => 'uuid',
    -value    => $the_id,
    -expires => '+20y',
);
print $q->header(-cookie => $uuid_cookie);
print "<meta http-equiv='refresh' content='0; URL=https://ultrabee.org/cgi-bin/nytbee_mkclues.pl/today'/>\n";
