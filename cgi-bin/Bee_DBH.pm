use strict;
use warnings;

package Bee_DBH;
use base 'Exporter';
our @EXPORT_OK = qw/
    $dbh
    get_person
    add_update_person
/;

use BeeUtil qw/
    ip_id
/;

use DBI;
our $dbh = DBI->connect(
    'dbi:mysql:logicalpoetr:spruce.safesecureweb.com',
    'logicalpoetr',
    'bx42rg86',
    { RaiseError => 1, AutoCommit => 1 }
) or die "cannot connect to database\n";

#
# see if person exists (based on ip, browser_signature)
# if not return undef
# else return $ip_id, $person_id, $name, $location
#
sub get_person {
    my $ip_id = ip_id();
    my $sth = $dbh->prepare(<<'EOS');

        SELECT id, name, location
          FROM bee_person
         WHERE ip_id = ?

EOS
    $sth->execute($ip_id);
    my ($person_id, $name, $location) = $sth->fetchrow_array();
    return ($ip_id, $person_id, $name, $location);
}

#
# pname and plocation is required
# we return $person_id - the index into bee_person
#
sub add_update_person {
    my ($pname, $plocation) = @_;

    $plocation ||= '';
    my ($ip_id, $person_id, $name, $location) = get_person();
    if ($person_id) {
        if ($name ne $pname || $location ne $plocation) {
            # existing identity but name or location changed
            my $up_sth = $dbh->prepare(<<'EOS');

            UPDATE bee_person
               SET name = ?, location = ?
             WHERE ip_id = ?

EOS
            $up_sth->execute($pname, $plocation, $ip_id);
        }
        # else name and location did not change
    }
    else {
        # new person
        my $ins_sth = $dbh->prepare(<<'EOS');

        INSERT 
          INTO bee_person
               (ip_id, name, location)
        VALUES (?, ?, ?)

EOS
        $ins_sth->execute($ip_id, $pname, $plocation);
        $person_id = $dbh->last_insert_id(undef, undef, 'bee_person', 'id');
    }
    return $person_id, $ip_id;
}

1;
