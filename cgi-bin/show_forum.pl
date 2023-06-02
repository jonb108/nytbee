#!/usr/bin/env perl
use strict;
use warnings;
use Bee_DBH qw/
    $dbh
/;
use BeeUtil qw/
    $log
    $cgi_dir
    mark_up
/;
use Time::Simple qw/
    get_time
/;
use Date::Simple qw/
    date
/;
use DB_File;
my %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';
my ($p_date, $screen_name, $post_to_edit, $bg_color, $text_color) = @ARGV;
my $post_text = '';
if ($post_to_edit) {
    my $get_sth = $dbh->prepare(<<"EOS");

        SELECT *
          FROM forum
         WHERE id = ?

EOS
    $get_sth->execute($post_to_edit);
    my $href = $get_sth->fetchrow_hashref();
    if ($href && $href->{screen_name} eq $screen_name) {
        system(qq!$cgi_dir/del_post.pl $post_to_edit "$screen_name"!);
        --$num_msgs{$p_date};
        $post_text = $href->{message};
        $post_text =~ s{<br>}{\n}xmsg;
    }
}
my $pics = '../nytbee/pics';
my $height = 'height=20';
print <<"EOH";
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
        document.getElementById(resp).innerHTML = '<img src=$pics/redflag.png $height>';
    }
}

function flag(i) {
    var url = 'https://logicalpoetry.com/cgi-bin/forum_flag.pl?id=' + i;
    xmlhttp.open('GET', url, true);
    xmlhttp.onreadystatechange = getIt;
    xmlhttp.send(null);
    return true;
}
function disable_span(id) {
    document.getElementById(id).disabled = true;
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
}
.flagged {
    color: red;
}
.stamp {
    color: #999999;
}
.share {
    background: $bg_color;
    color: $text_color;
}
</style>
Please share:<br>
<textarea rows=3 cols=40 name=forum_post id=forum_post class=share>$post_text</textarea><br>
<button id=post_it onclick="document.getElementById('post_it').style.pointerEvents = 'none';" style="font-size: 14pt" class=share>Submit</button>
<div class=post>
EOH
my $get_msgs_sth = $dbh->prepare(<<'EOS');
    SELECT *
      FROM forum
     WHERE p_date = ?
  ORDER BY m_date desc, m_time desc
EOS
$get_msgs_sth->execute($p_date);
while (my $href = $get_msgs_sth->fetchrow_hashref()) {
    my $t = get_time($href->{m_time})->ampm;
    if ($href->{p_date} ne $href->{m_date}) {
        $t .= ' ' . date($href->{m_date})->format("%D");
    }
    my $id = $href->{id};
    my $msg = mark_up($href->{message});
    my $flag = $href->{flagged}? "<span class=flagged><img src=$pics/redflag.png $height></span>"
              :                  "<span id=msg$id class='cursor_black flag' onclick='flag($id);'><img src=$pics/flag.png $height></span>";
    my ($e, $x) = ('', '');
    if ($href->{screen_name} eq $screen_name) {
        $e = "<span class=cursor_black id=e$id onclick='edit_post($id);'><img src=$pics/pencil.png $height></span> ";
        $x = "<span class=cursor_black id=x$id onclick='del_post($id);'><img src=../nytbee/pics/trashcan.png height=20></span> ";
    }
    print <<"EOH";
<span class=stamp>$href->{screen_name}&nbsp;&nbsp;$t</span> <span style='float: right'>$e$x$flag</span><br>
$msg
<br>
<hr class="hr">
EOH
}
print "</div>\n";
if ($post_text) {
    print "<script>setTimeout(() => { document.getElementById('forum_post').focus(); }, 20 );</script>\n";
}
