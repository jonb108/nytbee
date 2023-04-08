#!/usr/bin/env perl
use strict;
use warnings;
my %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';
use Bee_DBH qw/
    $dbh
/;
my $get_sth = $dbh->prepare(<<'EOS');
    SELECT *
      FROM forum
     WHERE flagged = 'Y'
  ORDER BY m_date, m_time
EOS
my $unflag_sth = $dbh->prepare(<<'EOS');
    UPDATE forum
       SET flagged = ''
     WHERE id = ?
EOS
my $del_sth = $dbh->prepare(<<'EOS');
    DELETE
      FROM forum
     WHERE id = ?
EOS
use CGI qw/
    :standard
    :cgi-lib
/;
use BeeUtil qw/
    $cgi_dir
/;
print header();
my %P = Vars();
if (keys %P) {
    my $n_unflagged = 0;
    my $n_deleted = 0;
    for my $k (sort keys %P) {
        my ($id, $p_date) = $k =~ m{\A m (\d+) _ (.*) \z}xms;
        if ($P{$k} eq 'u') {
            $unflag_sth->execute($id);
            ++$n_unflagged;
        }
        else {
            $del_sth->execute($id);
            --$num_msgs{$p_date};
            ++$n_deleted;
        }
    }
    print <<"EOH";
<html>
<head>
<style>
body {
    margin-left: .5in;
    margin-top: .5in;
    font-size: 16pt;
    font-family: Arial;
}
</style>
</head>
<body>
EOH
    printf "%3d UnFlagged<br>\n", $n_unflagged;
    printf "%3d Deleted<br>\n",   $n_deleted;
    print <<'EOH';
</body>
</html>
EOH
    exit;
}
print <<"EOH";
<html>
<head>
<style>
body {
    margin-left: .5in;
    margin-top: .5in;
}
body, th, td, button {
    font-size: 16pt;
    font-family: Arial;
}
button {
    background: lightgreen;
}
</style>
</head>
<body>
<h1>Flagged Messages</h1>
EOH
$get_sth->execute();
my $nrows = 0;
while (my $href = $get_sth->fetchrow_hashref()) {
    ++$nrows;
    if ($nrows == 1) {
        print <<'EOH';
<form method=POST>
<table cellpadding=5 border=1 width=90%>
<tr>
<th width=10% align=left>Date</th>
<th width=70% align=left>Message</th>
<th width=10%>UnFlag</th>
<th width=10%>Delete</th>
</tr>
EOH
    }
    my %P = %$href;
    my $puzzle = $P{p_date};
    if (my ($y, $m, $d) =
        $puzzle =~ m{\A (\d\d\d\d)(\d\d)(\d\d) \z}xms
    ) {
        for ($m, $d) {
            s{\A 0}{}xms;
        }
        $puzzle = "$m/$d";
    }
    print Tr(
        td($puzzle),
        td($P{message}),
        td({align => 'center'},
           "<input type=radio name=m$P{id}_$P{p_date} value='u' checked>"),
        td({align => 'center'},
           "<input type=radio name=m$P{id}_$P{p_date} value='d'>"),
    ), "\n";
}
if ($nrows) {
    print <<'EOH';
</table>
<p>
<button type=submit>Submit</button>
EOH
}
else {
    print "No messages were flagged.\n";
}
print <<'EOH';
</body>
</html>
EOH
