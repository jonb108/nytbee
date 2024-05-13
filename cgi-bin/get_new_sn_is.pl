#!/usr/bin/env perl
use strict; 
use warnings;
# no duplicate SN or ID
use CGI;
my $q = CGI->new;
my $uuid = $q->param('uuid');
my $screen_name = $q->param('screen_name');
my $identity_string = $q->param('identity_string');
my $cur_game = $q->param('cur_game');
for ($screen_name, $identity_string) {
    s{\A \s*|\s* \z}{}xmsg;     # trim leading and trailing blanks
}
my @base = qw/
    Bee
    Drone
    Queen
    Hive
    Worker
    Bumble
    Honey
    Apian
    Buzz
/;
my $base = join '|', @base;
if ($screen_name =~ m{\A ($base)\d+ \z}xms) {
    print $q->header();
    print "The screen name '$screen_name' cannot look like a randomly assigned name.\n";
    exit;
}

use BeeDBM qw/
    %screen_name_uuid
    %uuid_screen_name
    %cur_puzzles_store
    %uuid_colors_for
    %end_time_for
    %message_for
/;

my $style = <<'EOH';
<style>
body {
    margin: .5in;
    font-size: 18pt;
}
.back {
    text-decoration: underline;
    color: "blue";
    cursor: pointer;
    onclick="window.history.back();
}
</style>
EOH
sub oops {
    my ($msg) = @_;
    print $q->header();
    print <<"EOH";
$style
$msg
<p>
<span class=back onclick="window.history.back();">
Go back</span> and try again.
EOH
    exit;
}

# duplicates?
if (exists $screen_name_uuid{$screen_name}) {
    oops "Sorry, the screen name '$screen_name' is already taken.<p>";
}
if (exists $uuid_screen_name{$identity_string}) {
    oops "Sorry, the identity string '$identity_string' is already taken.<p>";
}

$cur_puzzles_store{$identity_string} = $cur_puzzles_store{$uuid};
delete $cur_puzzles_store{$uuid};

$uuid_screen_name{$identity_string} = $screen_name;
$screen_name_uuid{$screen_name} = $identity_string;
delete $screen_name_uuid{$uuid_screen_name{$uuid}};  # old screen name
delete $uuid_screen_name{$uuid};

$uuid_colors_for{$identity_string} = $uuid_colors_for{$uuid};
delete $uuid_colors_for{$uuid};

my $uuid11 = substr($uuid, 0, 11);
$end_time_for{substr($identity_string, 0, 11)} = $end_time_for{$uuid11};
delete $end_time_for{$uuid11};

$message_for{$identity_string} = $message_for{$uuid};
delete $message_for{$uuid};

my $uuid_cookie = $q->cookie(
    -name    => 'uuid',
    -value    => $identity_string,
    -expires => '+20y',
);
print $q->header(-cookie => $uuid_cookie), $style;
print "Thank you.  You can <a href='https://logicalpoetry.com/cgi-bin/nytbee.pl/$cur_game'>resume playing</a> the game!\n";
