use strict;
use warnings;

package Bee_DBH;
use base 'Exporter';
our @EXPORT_OK = qw/
    $dbh
    get_person
    add_update_person
    get_clues
/;

use BeeUtil qw/
    ip_id
/;
use JSON::PP qw/
    encode_json
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
# and the corresponding $ip_id
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

#
# given a person and a set of words
# look in the database and see what clues the person
# has given for the words before.
# return an href - key = word, value either a clue or an aref of clues
# the clues in the aref should be unique
# and a JSON string of the words with more than one clue
#     the JSON is a href: key = word
#                    value = href: keys cur => 0, clues => aref of clues
#     {
#         noon => { cur => 0, clues => [ 'Mid', 'John', 'Pal', 'Sun' ] },
#         toon => { cur => 0, clues => [ 'Car', 'Fun' ] }, 
#         ...
#     }
#
# we also pass an href of _existing clues_
#     key word, value clue
# no guarantee that every word in keys of existing clues
#    is in the $words_aref or vica versa
# if there is an existing clue make sure it is first
#    in the returned href of prior clues
#
sub get_clues {
    my ($person_id, $words_aref, $href_existing_clue_for) = @_;

    if (! $person_id || !@$words_aref) {
        return {}, '{}';
    }
    my $words = join ', ',
                map {
                    "'$_'"
                }
                @{$words_aref};
    my $sth_clue = $dbh->prepare(<<"EOS");

        SELECT distinct word, clue
          FROM bee_clue
         WHERE person_id = ?
           AND word IN ($words)
      ORDER BY date desc;

EOS
    $sth_clue->execute($person_id);
    my %prior_clues_for;
    while (my ($word, $clue) = $sth_clue->fetchrow_array()) {
        if (exists $prior_clues_for{$word}) {
            if (ref $prior_clues_for{$word} eq 'ARRAY') {
                push @{$prior_clues_for{$word}}, $clue;
            }
            else {
                my $clue1 = $prior_clues_for{$word};
                $prior_clues_for{$word} = [ $clue1, $clue ];
            }
        }
        else {
            $prior_clues_for{$word} = $clue;
        }
    }

    for my $w (keys %prior_clues_for) {
        if (exists $href_existing_clue_for->{$w}) {
            # this clue is either a singleton
            # in which case it is the same clue and all is well
            # OR it is in the aref somewhere.
            # in this case, move it to the front
            if (ref $prior_clues_for{$w} eq 'ARRAY') {
                my $clue = $href_existing_clue_for->{$w};
                my $aref = $prior_clues_for{$w};
                @$aref = ($clue, grep { $_ ne $clue } @$aref);
            }
        }
    }

    # for the words that have multiple prior clues
    # we craft a JSON string.
    #
    my %clues_for_json;
    for my $w (@{$words_aref}) {
        if (ref $prior_clues_for{$w} eq 'ARRAY') {
            $clues_for_json{$w} = {
                clues => $prior_clues_for{$w},
                cur   => 0,
            };
        }
    }
    my $json = encode_json(\%clues_for_json);

    return \%prior_clues_for, $json;
}

1;
