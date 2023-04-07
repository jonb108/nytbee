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
<script>
// prepare for an Ajax call:
var xmlhttp = false;
var ua = navigator.userAgent.toLowerCase();
if (!window.ActiveXObject)
    xmlhttp = new XMLHttpRequest();
else if (ua.indexOf('msie 5') == -1)
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
else
    xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");

function getIt() {
    if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
        var resp = xmlhttp.responseText;
        document.getElementById(resp).innerHTML = '<span class=red>Flagged</span>';
    }
}

function flag(i) {
    var url = 'https://logicalpoetry.com/cgi-bin/forum_flag.pl?id=' + i;
    xmlhttp.open('GET', url, true);
    xmlhttp.onreadystatechange = getIt;
    xmlhttp.send(null);
    return true;
}
</script>
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
    color: #dddddd;
    float: right;
}
.flagged {
    color: red;
    float: right;
}
.stamp {
    color: #999999;
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
    my $id = $href->{id};
    my $msg = $href->{message};
    $msg =~ s{(https?://\S+)}{<a target=_blank href='$1'>$1</a>}xmsg;
    my $flag = $href->{flagged}? "<span class=flagged>Flagged</span>"
              :                  "<span id=msg$id class='flag cursor_black' onclick='flag($id);'>Flag</span>";
    print <<"EOH";
<span class=stamp>$href->{screen_name}&nbsp;&nbsp;$t</span> $flag<br>
$msg
<br>
<hr class="hr">
EOH
}
print "</div>\n";
