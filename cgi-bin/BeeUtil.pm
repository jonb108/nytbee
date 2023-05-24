use strict;
use warnings;
package BeeUtil;
use base 'Exporter';
our @EXPORT_OK = qw/
    ymd
    cgi_header
    uniq_chars
    uniq_words
    extra_let
    error
    word_score
    trim
    table
    Tr
    th
    td
    div
    span
    ul
    bold
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
    set_colors
    get_colors
/;
use BeeDBM qw/
    %uuid_colors_for
/;
use Date::Simple qw/
    today
/;
use DB_File;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

our $log     = 'https://logicalpoetry.com';
our $cgi     = 'https://logicalpoetry.com/cgi-bin';
our $cgi_dir = '/home4/logical9/www/cgi-bin';
our $thumbs_up = '&#128077;';

#
# handle the creation and maintenance of the uuid
#
sub cgi_header {
    my ($q, $another_cookie) = @_;

    my $cmd = $q->param('new_words');
    my $uuid;
    if ($cmd && $cmd =~ m{\A id \s+ (\S+) \s* \z}xmsi) {
        $uuid = $1;
    }
    else {
        $uuid = $q->cookie('uuid');
    }
    if (! $uuid) {
        # only load this module if it is needed
        require UUID::Tiny;
        $uuid = UUID::Tiny::create_uuid_as_string(1);
    }
    elsif ($cmd && $cmd =~ m{\A idk \s+ (\S+) \s* \z}xms) {
        my $new_uuid = $1;
        # get the puzzle store (and message #) for $uuid
        # and copy it to the new uuid.
        #
        my %cur_puzzles_store;
        tie %cur_puzzles_store, 'DB_File', 'cur_puzzles_store.dbm';
        my $puz = $cur_puzzles_store{$uuid};

        my %message_for;
        tie %message_for, 'DB_File', 'message_for.dbm';
        my $msg = $message_for{$uuid};

        $uuid = $new_uuid;
        $cur_puzzles_store{$uuid} = $puz;
        $message_for{$uuid} = $msg;
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
    $s =~ s{\A [^a-z0-9+#-]}{}xmsgi;  # mobile H3 related? don't know why...
    $s =~ s{\A \s* | \s* \z}{}xmsg;
    return $s;
}

sub _attrs {
    my $href = shift;
    return ' ' . join ' ',
           map { "$_='$href->{$_}'" }
           keys %$href;
}
sub table {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<table$attrs>@_</table>";
}
sub div {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<div$attrs>@_</div>";
}
sub span {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<span$attrs>@_</span>";
}
sub Tr {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<tr$attrs>@_</tr>";
}
sub th {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<th$attrs>@_</th>";
}
sub td {
    my $attrs = ref $_[0] eq 'HASH'? _attrs(shift): '';
    return "<td$attrs>@_</td>";
}
sub ul {
    return "<ul>@_</ul>";
}
sub bold {
    return "<b>@_</b>";
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

my %valid_color = map { lc $_ => 1 } qw/
AliceBlue AntiqueWhite Aqua Aquamarine Azure Beige Bisque Black BlanchedAlmond
Blue BlueViolet Brown BurlyWood CadetBlue Chartreuse Chocolate Coral
CornflowerBlue Cornsilk Crimson Cyan DarkBlue DarkCyan DarkGoldenRod
DarkGray DarkGrey
DarkGreen DarkKhaki DarkMagenta DarkOliveGreen Darkorange DarkOrchid
DarkRed DarkSalmon DarkSeaGreen DarkSlateBlue
DarkSlateGray DarkSlateGrey
DarkTurquoise DarkViolet DeepPink DeepSkyBlue
DimGray DimGrey
DodgerBlue FireBrick FloralWhite ForestGreen Fuchsia
Gainsboro GhostWhite Gold GoldenRod
Gray Grey
Green GreenYellow HoneyDew HotPink IndianRed Indigo Ivory Khaki
Lavender LavenderBlush LawnGreen LemonChiffon LightBlue
LightCoral LightCyan LightGoldenRodYellow
LightGrey LightGreen
LightPink LightSalmon LightSeaGreen LightSkyBlue
LightSlateGray LightSlateGrey
LightSteelBlue LightYellow Lime LimeGreen Linen Magenta Maroon
MediumAquaMarine MediumBlue MediumOrchid MediumPurple MediumSeaGreen
MediumSlateBlue MediumSpringGreen MediumTurquoise MediumVioletRed 
MidnightBlue MintCream MistyRose Moccasin NavajoWhite
Navy OldLace Olive OliveDrab Orange OrangeRed Orchid
PaleGoldenRod PaleGreen PaleTurquoise PaleVioletRed PapayaWhip
PeachPuff Peru Pink Plum PowderBlue Purple Red RosyBrown RoyalBlue
SaddleBrown Salmon SandyBrown SeaGreen SeaShell Sienna
Silver SkyBlue SlateBlue
SlateGray SlateGrey
Snow SpringGreen SteelBlue Tan Teal Thistle Tomato
Turquoise Violet Wheat White WhiteSmoke Yellow YellowGreen
/;

sub squish {
    my ($s) = @_;
    $s =~ s{\s}{}xmsg;
    return $s;
}
sub within {
    my ($n) = @_;
    return 0 <= $n && $n <= 255;
}
sub set_colors {
    my ($uuid, $color_param) = @_;
    my %colors = get_colors($uuid);
    # tidy up rgb(a,b,c)
    $color_param =~ s{ [(] ([^)]*) [)] }{'(' . squish($1) . ')'}xmsge;
    my @new_colors = split ' ', $color_param;
    if (@new_colors == 1 && $new_colors[0] eq 'a') {
        # standard colors
        $colors{center_hex} = 'gold';
        $colors{center_text} = 'black';
        $colors{donut_hex} = '#e7e7e7';
        $colors{donut_text} = 'black';
        $colors{background} = 'white',
        $colors{letter} = 'black',
        $colors{alink} = 'blue',
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'd') {
        # dark mode standard colors
        $colors{center_hex} = 'gold';
        $colors{center_text} = 'black';
        $colors{donut_hex} = '#e7e7e7';
        $colors{donut_text} = 'black';
        $colors{background} = 'black',
        $colors{letter} = 'white',
        $colors{alink} = 'skyblue',
    }
    else {
        # validate the colors
        my @bad;
        my @name = qw/
            center_hex
            center_text
            donut_hex
            donut_text
            background
            letter
            alink
        /;
        for my $i (0 .. $#new_colors) {
            my $c = $new_colors[$i];
            if ($c eq '.') {
                $new_colors[$i] = $colors{$name[$i]};
            }
            elsif ($valid_color{$c}) {
                # ok
            }
            elsif ($c =~ m{\A [#][a-f0-9]{6} \z }xms) {
                # ok
            }
            elsif ($c =~ m{\A rgb[(](\d+),(\d+),(\d+)[)] \z}xms
                   && within($1) && within($2) && within($3)
            ) {
                # ok
            }
            elsif ($c =~ m{\A gr[ae]y (\d+) \z}xms) {
                my $x = $1;
                if (0 <= $x && $x <= 100) {
                    my $y = 255*($x/100);
                    $new_colors[$i] = sprintf "rgb(%d,%d,%d)", $y, $y, $y;
                }
                else {
                    push @bad, uc $c;
                }
            }
            else {
                push @bad, uc $c;
            }
        }
        if (@bad) {
            my $pl = @bad == 1? '': 's';
            return "Invalid color$pl: " . join(', ', @bad);
        }
        for my $i (0 .. $#new_colors) {
            $colors{$name[$i]} = $new_colors[$i];
        }
    }
    $uuid_colors_for{$uuid} = Dumper(\%colors);
    return '';
}
# returns a hash with 7 keys
sub get_colors {
    my ($uuid) = @_;
    if ($uuid_colors_for{$uuid}) {
        return %{ eval $uuid_colors_for{$uuid} };
    }
    else {
        return (
            center_hex => 'gold',
            center_text => 'black',
            donut_hex => 'lightgray',
            donut_text => 'black',
            background => 'white',
            letter => 'black',
            alink => 'blue',
        );
    }
}

1;
