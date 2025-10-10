#!/usr/bin/perl
use warnings;
use strict;
use Bee_DBH qw/
    $dbh
/;
use BeeUtil qw/
    $cgi
    slash_date
    mark_up
/;
use Time::Simple qw/
    get_time
/;
my $query = shift;
my $the_query;
my $where;
if ($query =~ s{\s+ s \z}{}xms) {
    # substring query
    $the_query = "%$query%";
    $where = "message like ? OR screen_name like ?";
}
else {
    # word boundary query
    my $start = "[[:<:]]";
    my $end   = "[[:>:]]";
    $the_query = "$start$query$end";
    $where = "message REGEXP ? OR screen_name REGEXP ?";
}
my $show_query = $query;
# m_time
# m_date
# p_date
# screen_name
# message
my $sth = $dbh->prepare(<<"EOS");
    SELECT *
      FROM forum
     WHERE $where
  ORDER BY p_date desc, m_date desc, m_time desc
EOS
$sth->execute($the_query, $the_query);
print <<'EOH';
<style>
.ital {
    font-style: italic;
}
hr {
    margin-top: 5mm;
    margin-bottom: 5mm;
}
</style>
EOH

print "Searching forum for '$show_query':<p>\n";
my $sp = "&nbsp;" x 4;
while (my $href = $sth->fetchrow_hashref()) {
    my $dt = slash_date($href->{p_date});
    my $tm = get_time($href->{m_time})->ampm();
    my $sn = $href->{screen_name};
    my $msg = mark_up($href->{message});
    for ($sn, $msg) {
        s{($query)}{<span class=ital>$1</span>}xmsgi
            unless $query =~ m{\A \d+ \z}xms;
            # the above is needed for 'F 128029'
            # when searching for an emoticon
            # clever to use $1 to undo the case insensitivity
    }
    print "\@$sn"
        . "$sp<a class=alink href='$cgi/nytbee.pl/$href->{p_date}?forum_mode=1'>$dt</a>"
        . "$sp$tm"
        . "<p>$msg<hr>\n"
          ;
}
