use strict;
use warnings;
package BeeUtil;
use base 'Exporter';
our @EXPORT_OK = qw/
    ymd
    cgi_header
    uniq_chars
    uniq_words
    jumble
    extra_let
    error
    word_score
    trim
    slash_date
    shuffle
    JON
    red
    my_today
    $log
    $cgi
    $cgi_dir
    get_html
    $thumbs_up
    mark_up
    puzzle_info
/;
use Date::Simple qw/
    today
/;
use DB_File;

our $log     = 'https://ultrabee.org';
our $cgi     = 'https://ultrabee.org/cgi-bin';
our $cgi_dir = '/home4/logical9/www/ultrabee/cgi-bin';
our $thumbs_up = '&#128077;';

#use BeeDBM qw/
#    %cur_puzzles_store
#    %settings_for
#/;

#
# handle the creation and maintenance of the uuid
#
sub cgi_header {
    my ($q, $another_cookie) = @_;

    my $cmd = $q->param('new_words');
    my $uuid;
    if ($cmd && $cmd =~ m{\A \s* id \s+ (\S+) \s* \z}xmsi) {
        $uuid = lc $1;
#        my $old_uuid = lc $q->cookie('uuid');
#        # check for generated one??
#
# 18d7edac-6fee-11ed-a97e-8c36b52268c0
# 0123456789012345678901234567890
#           1         2         3
#sub long_form {
#    my ($uuid) = @_;
#    return substr($uuid,  8, 1) eq '-'
#        && substr($uuid, 13, 1) eq '-'
#        && substr($uuid, 18, 1) eq '-'
#        && substr($uuid, 23, 1) eq '-'? 1: 0;
#}
#        $cur_puzzles_store{$uuid} = $cur_puzzles_store{$old_uuid};
#        delete $cur_puzzles_store{$old_uuid};
#
#        # colors
#        my %uuid_colors_for;
#        my %uuid_color_schemes_for;
#        tie %uuid_colors_for, 'DB_File', 'uuid_colors_for.dbm';
#        tie %uuid_color_schemes_for, 'DB_File', 'uuid_color_schemes_for.dbm';
#        if (exists $uuid_colors_for{$old_uuid}) {
#            $uuid_colors_for{$uuid} = $uuid_colors_for{$old_uuid};
#            delete $uuid_colors_for{$old_uuid};
#        }
#        if (exists $uuid_color_schemes_for{$old_uuid}) {
#            $uuid_color_schemes_for{$uuid} = $uuid_color_schemes_for{$old_uuid};
#            delete $uuid_color_schemes_for{$old_uuid};
#        }
#        untie %uuid_colors_for;
#        untie %uuid_color_schemes_for;
#
#        # settings
#        if (exists $settings_for{$old_uuid}) {
#            $settings_for{$uuid} = $settings_for{$old_uuid};
#            delete $settings_for{$old_uuid};
#        }
    }
    elsif ($cmd && $cmd =~ m{\A \s* ~pb \s+ (\S+)}xmsi) {
        # undocumented
        my $screen_name = lc $1;
        my %screen_name_uuid;
        my %full_uuid;
        tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';
        tie %full_uuid, 'DB_File', 'full_uuid.dbm';
        EACH:
        while (my ($sn, $ui) = each %screen_name_uuid) {
            if ($screen_name eq lc $sn) {
                $uuid = $full_uuid{$ui};
                last EACH;
            }
        }
        untie %screen_name_uuid;
        untie %full_uuid;
        if (! $uuid) {
            $uuid = lc $q->cookie('uuid');
        }
    }
    else {
        $uuid = lc $q->cookie('uuid');
    }
    if (! $uuid) {
        # only load this module if it is needed
        require UUID::Tiny;
        $uuid = UUID::Tiny::create_uuid_as_string(1);
    }
    my $uuid_cookie = $q->cookie(
        -name    => 'uuid',
        -value    => $uuid,
        -expires => '+20y',
    );
    if ($another_cookie) {
        print $q->header(-cookie => [ $uuid_cookie, $another_cookie ]);
    }
    else {
        print $q->header(-cookie => $uuid_cookie);
    }
    return $uuid;
}

sub my_today {
    my ($hour) = (localtime)[2];
    my $today = today();
    if ($hour < 1) {
        # the machine is in MST
        # and the "next day" doesn't start until 3:00 AM EST
        --$today;
    }
    return $today;
}

sub slash_date {
    my ($d8) = @_;
    if ($d8 =~ m{\A CP}xmsi) {
        return uc $d8;
    }
    my ($y, $m, $d) = $d8 =~ m{\A ..(..)(..)(..) \z}xms;
    return "$m/$d/$y";
}

sub uniq_chars {
    my ($word) = @_;
    my %seen;
    my @chars = sort grep { !$seen{$_}++; } split //, $word;
    return @chars;
}

sub uniq_words {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub jumble {
    my ($w) = @_;
    my @chars = split '', $w;
    my $jw = '';
    while (@chars) {
        $jw .= splice @chars, int(rand(@chars)), 1;
    }
    return $jw eq $w? jumble($w): $jw;
}

sub error {
    my ($msg) = @_;
    print <<"EOH";
<style>
body {
    margin-top: .5in;
    margin-left: .5in;
    font-family: Arial;
    font-size: 18pt;
}
.back {
    font-size: 18pt;
    background: lightgreen;
}
</style>
$msg
<p>
Please <button class=back id=back onclick="history.go(-1)">Go Back</button> and fix this.
<script type='text/javascript'>document.getElementById('back').focus();</script>
EOH
    exit;
}

sub word_score {
    my ($word, $pangram) = @_;
    my $l = length $word;
    return ($l == 4? 1: $l) + ($pangram? 7: 0);
}

sub trim {
    my ($s) = @_;
    #$s =~ s{\A [^a-z0-9+#-]}{}xmsgi;  # mobile H3 related? don't know why...
    $s =~ s{\A \s* | \s* \z}{}xmsg;
    return $s;
}

sub shuffle {
    my (@elems) = @_;
    my @new;
    push @new, splice @elems, rand @elems, 1 while @elems;
    return @new;
}

sub red {
    return "<span class=red1>@_</span>";
}

sub JON {
    open my $jon, '>>', '/tmp/jon';
    print {$jon} "@_\n";
    close $jon;
}

sub get_html {
    my ($url) = @_;
    require LWP::Simple;
    return LWP::Simple::get($url);
}

sub ymd {
    my $today = my_today();
    return $today->format("%Y%m%d");
}

sub extra_let {
    my ($word, $seven) = @_;
    $word =~ s{[$seven]}{}xmsg;
    return substr($word, 0, 1);
}

sub screen_name {
    my ($uuid) = @_;
    return `screen_name.pl $uuid`;
}

sub mark_up {
    my ($s) = @_;
    $s =~ s{}{<p>}xms;
    $s =~ s{\n\n}{<p>}xms;
    $s =~ s{}{<br>}xms;
    $s =~ s{[<][^>]*[>]}{}xms;  # no HTML tags, please
    $s =~ s{[*]([^*]*)[*]}{<b>$1</b>}xmsg;
    $s =~ s{[_]([^_]*)[_]}{<u>$1</u>}xmsg;
    $s =~ s{(http\S*)}{<a target=_blank href='$1'>$1</a>}xmsg;
    $s =~ s{([\w._]+[@]\S*)}{<a target=_blank href='mailto:$1'>$1</a>}xmsg;
    return $s;
}

#
#  input: two array refs to words and pangrams
# output: $nwords, $max_score,
#         $npangrams, $nperfect,
#         $bingo, $gn4l, $gn4l_np
#
#  where $bingo, $gn4l, and $gn4l_np are either 0 or 1.
#
sub puzzle_info {
    my ($words_aref, $pangrams_aref) = @_;

    my %is_pangram = map { $_ => 1 } @$pangrams_aref;
    my $npangrams = @$pangrams_aref;
    my $nperfect = 0;
    for my $p (@$pangrams_aref) {
        if (length $p == 7) {
            ++$nperfect;
        }
    }
    my $max_score = 0;
    my $gn4l_score = 0;
    my $gn4l_np_score = 0;
    my $nwords = @$words_aref;
    my %first_letter;
    for my $w (@$words_aref) {
        ++$first_letter{substr($w, 0, 1)};
        my $lw = length $w;
        if ($lw == 4) {
            $max_score += 1;
        }
        else {
            if ($is_pangram{$w}) {
                my $word_score = $lw + 7;
                $max_score += $word_score;
                $gn4l_score += $word_score;
            }
            else {
                $max_score += $lw;
                $gn4l_score += $lw;
                $gn4l_np_score += $lw;
            }
        }
    }
    my $bingo = keys %first_letter == 7? 1: 0;
    my $genius = int(70*$max_score/100);
    my $gn4l    = $gn4l_score    >= $genius? 1: 0;
    my $gn4l_np = $gn4l_np_score >= $genius? 1: 0;
    return ($nwords, $max_score, $npangrams, $nperfect, $bingo,
            $gn4l, $gn4l_np); 
}

1;
