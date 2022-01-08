use strict;
use warnings;

package Bee_DBH;
use base 'Exporter';
our @EXPORT_OK = qw/
    $dbh
/;

use DBI;
our $dbh = DBI->connect(
    'dbi:mysql:logicalpoetr:spruce.safesecureweb.com',
    'logicalpoetr',
    'bx42rg86',
    { RaiseError => 1, AutoCommit => 1 }
) or die "cannot connect to database\n";

1;
