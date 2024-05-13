#!/usr/bin/env perl
# new_sn_is = New Screen Name and Identity String
use strict;
use warnings;
my ($screen_name, $sn, $uuid, $lf, $cur_game) = @ARGV;
open my $log, '>>', 'sn_is_log.txt';
print {$log} "$screen_name - $uuid = in dialog\n";
close $log;
my $disp_screen_name;
if ($sn) {
    # the screen name was a boring assigned one
    # like Drone45 or Queen51
    $screen_name = '';
}
else {
    $disp_screen_name = " $screen_name";
}
my $identity_string;
if ($lf) {
    # "long form"
    # the identity string was a generated one
    $identity_string = '';
}
else {
    $identity_string = $uuid;
}
print <<"EOH";
<html>
<head>
<meta charset='UTF-8'>
<style>
body {
    font-family: Helvetica;
    margin: .5in;
    margin-top: .3in;
    width: 70%;
}
body, input, th, td {
    font-size: 14pt;
}
th {
    text-align: right;
}
.green {
    background: lightgreen;
}
.cmd {
    color: darkred;
}
</style>
<script type="text/javascript">
function check_strings() {
    var el1 = document.getElementById('screen_name');
    var v = el1.value;
    var non_blank = new RegExp('\\\\S'); /* ?? */
    if (! non_blank.test(v)) {
        alert('The screen name cannot be blank.');
        setTimeout(function() {
            el1.focus();
        }, 0);
        el1.focus();
        return false;
    }
    var rexp1 = new RegExp('[<> ]');
    if (rexp1.test(v)) {
        alert('Sorry, you cannot use <, >, or the space character in the screen name.');
        setTimeout(function() {
            el1.focus();
        }, 0);
        return false;
    }
    var is = document.getElementById('identity_string');
    var v2 = is.value;
    if (! non_blank.test(v2)) {
        alert('The identity string cannot be blank.');
        setTimeout(function() {
            is.focus();
        }, 0);
        return false;
    }
    return true;
}
</script>
</head>
<body>
Greetings$disp_screen_name,
<img style='margin-left: 1in' src=https://logicalpoetry.com/nytbee/pics/bee-logo.png>
<p>
It's great that you are enjoying the Enhanced NYT Bee.<br>
Please set two simple things.  You can then continue your game.
<p>
The <b>Screen Name</b> is used to publicly identify you when reporting
how everyone is doing on the puzzle (the <span class=cmd>TOP</span> and <span class=cmd>CW</span> commands).  It can be in mixed case &ndash; like 'BeeCool'
<p>
The <b>Identity String</b> is used when storing your
list of games and your choice of colors.
This string is private.  It can be <i>anything</i> but make it easily remembered!
<p>
Note that you do not need to share <i>any</i> personal information.
<p>
<form name=form
      action='https://logicalpoetry.com/cgi-bin/get_new_sn_is.pl'
      onsubmit="return check_strings()"
>
<input type=hidden name=uuid value='$uuid'>
<input type=hidden name=cur_game value='$cur_game'>
<table cellpadding=5>
<tr><th>Screen Name</th><td><input type=text name=screen_name id=screen_name size=20 value='$screen_name'></td></tr>
<tr><th>Identity String</th><td><input type=text name=identity_string id=identity_string size=20 value='$identity_string'></td></tr>
<tr><th>&nbsp;</td><td><input class=green type=submit value='Submit'></td></tr>
</table>
</form>
<p>
You can read more about these two things by
<a target=_blank href='https://logicalpoetry.com/nytbee/help.html#screen_names'>clicking here</a>.
</body>
</html>
<script type="text/javascript">
document.form.screen_name.focus();
</script>
EOH
