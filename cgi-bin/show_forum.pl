#!/usr/bin/env perl
use strict;
use warnings;
use Bee_DBH qw/
    $dbh
/;
use BeeUtil qw/
    $log
/;
use Time::Simple qw/
    get_time
/;
use Date::Simple qw/
    date
/;
my $p_date = shift;
print <<'EOH';
<style>
.hr {
    margin-left: 0px;
    margin-top: 5mm;
    margin-bottom: 5mm;
    width: 600px;
}
.post {
    width: 600px;
}
.flag {
    color: #eeeeee;
    float: right;
}
.flagged {
    color: red;
    float: right;
}
.stamp {
    color: #aaaaaa;
}
</style>
Please share:<br>
<textarea rows=3 cols=40 name=forum_post>
</textarea><br>
<button style="font-size: 14pt">Submit</button>
<div class=post>
EOH
my $get_msgs_sth = $dbh->prepare(<<'EOS');
    SELECT *
      FROM forum
     WHERE p_date = ?
  ORDER BY m_time desc
EOS
$get_msgs_sth->execute($p_date);
while (my $href = $get_msgs_sth->fetchrow_hashref()) {
    my $t = get_time($href->{m_time})->ampm;
    if ($href->{p_date} ne $href->{m_date}) {
        $t .= ' ' . date($href->{m_date})->format("%D");
    }
    my $flag = $href->{flagged}? "<span class=flagged>Flagged</span>"
              :                  "<span class=flag>Flag</span>";
    print <<"EOH";
<span class=stamp>$href->{screen_name}&nbsp;&nbsp;$t</span> $flag<br>
$href->{message}
<br>
<hr class="hr">
EOH
}
print "</div>\n";
