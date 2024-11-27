#!/usr/bin/env perl
use strict;
use warnings;

# right befor executing this:
#  mv full_uuid.dbm copy_full_uuid.dbm

# then the full_uuid.dbm file will have everyone
# for some reason it gets corrupted periodically.

use DB_File;
our %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
our %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';

while (my ($k, $v) = each %cur_puzzles_store) {
    my $k11 = substr($k, 0, 11);
    $full_uuid{$k11} = $k;
}
