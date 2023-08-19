#!/usr/bin/env perl
use strict;
use warnings;
use CGI;
my $q = CGI->new();
print $q->header;
print <<'EOH';
<html>
<head>
<style>
body, th, td {
    margin: .5in;
    font-size: 16pt;
}
a {
    text-decoration: none;
    color: black;
}
</style>
</head>
<body>
EOH
my %params = $q->Vars();
use DB_File;
my %missing_words;
tie %missing_words, 'DB_File', 'missing_words.dbm';
my %added_words;
tie %added_words, 'DB_File', 'added_words.dbm';
# key: date/cp#
# value: number of messages in the forum for this puzzle
my %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';

use Time::Simple qw/
    get_time
/;
use Date::Simple qw/
    today
/;
use Bee_DBH qw/
    $dbh
/;
use LWP::Simple qw/
    get
/;

if (! %params) {
    my @words = sort keys %missing_words;
    if (! @words) {
        print "There are no recently submitted Missing Words.<p>\n";
        exit;
    }
    print "<div style='width: 80%'>These are the recently submitted Missing Words.<p>\n";
    print "Click on the words for a definition from <a target=_blank style='color: blue' href='https://wordnik.com'>wordnik.com</a>.";
    print " Words with no definition are marked ???.</div><p>\n";
    print "<form>\n";
    print "<table cellpadding=3>\n";
    print "<tr><th></th><th>Add</th><th>Delete</th><th>Defer</th></tr>\n";
    for my $w (@words) {
        my $def = get("https://wordnik.com/words/$w");
        my $no_def = $def =~ m{Sorry,\s*no\s*definitions\s*found}xms? '???': '';
        my $W = ucfirst $w;
        print "<tr><td><a target=_blank href='https://wordnik.com/words/$w'>$W</a></td>";
        print "<td align=center><input type=radio name=$w value=add checked>";
        print "<td align=center><input type=radio name=$w value=delete>\n";
        print "<td align=center><input type=radio name=$w value=defer>\n";
        if ($missing_words{$w} != 1) {
            my $s = $missing_words{$w};
            if ($s =~ m{\A (....)(..)(..) \z}xms) {
                $s = "$2/$3/$1";
            }
            print "<td><a target=_blank style='color: blue' href='https://logicalpoetry.com/cgi-bin/nytbee.pl?new_words=$missing_words{$w}'>$s</a></td>\n";
        }
        if ($no_def) {
            print "<td>???</td>";
        }
        print "</tr>\n";
    }
    print "</table><p>\n";
    print "<input type=submit style='background: lightgreen; font-size: 16pt; margin-left: .5in;'>\n";
    print "</form>";
}
else {
    my @deleted;
    my $n_added = 0;
    for my $w (sort keys %params) {
        if ($params{$w} eq 'add' && ! exists $added_words{$w}) {
            delete $missing_words{$w};
            $added_words{$w} = 1;
            ++$n_added;
        }
        elsif ($params{$w} eq 'delete' && exists $missing_words{$w}) {
            delete $missing_words{$w};
            push @deleted, ucfirst $w;
        }
        else {
            # deferred
        }
    }
    my $del_msg = '';
    if (@deleted) {
        my $del = @deleted == 1? "This word was": "These words were";
        $del_msg = "<br>$del NOT added: @deleted.";
    }
    my $ins_sth = $dbh->prepare(<<'EOS');

        INSERT
          INTO forum
             (screen_name,
              m_date, m_time,
              p_date, message,
              flagged)
         VALUES (?,
                 ?, ?,
                 ?, ?,
                 '');

EOS
    my $now = get_time();
    $now->{minutes} -= 60;
    my $pl = $n_added == 1? '': 's';
    my $today_d8 = today()->as_d8();
    my $message = "Added $n_added missing word$pl.$del_msg ";
    $ins_sth->execute('BeeAdmin',
                      $today_d8, $now->t24,
                      $today_d8,
                      $message,
                     );
    ++$num_msgs{$today_d8};
    print $message;
}
print <<'EOH';
</body>
</html>
EOH
