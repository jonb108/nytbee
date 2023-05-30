use strict;
use warnings;
package BeeColor;
use base 'Exporter';
our @EXPORT_OK = qw/
    get_colors
    set_colors
    save_colors
    color_schemes
    del_scheme
/;
use DB_File;
our %uuid_colors_for;
tie %uuid_colors_for, 'DB_File', 'uuid_colors_for.dbm';
# key is uuid
# value is a string of 9 colors
our %uuid_color_schemes_for;
tie %uuid_color_schemes_for, 'DB_File', 'uuid_color_schemes_for.dbm';
# key is uuid
# values is a Dumper string representing a hash ref with
#   key of scheme name
#   value of a string of 9 colors

use BeeDBM qw/
    %uuid_colors_for
/;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

my @names = qw/
    center_hex
    center_text
    donut_hex
    donut_text
    background
    letter
    alink
    bg_input
    text_input
/;
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
sub mqw {
    my ($s) = @_;
    return split ' ', $s;
}
sub set_colors {
    my ($uuid, $color_param) = @_;
    # . to ' . ' so we don't have to insert spaces between dots
    $color_param =~ s{[.]}{ . }xmsg;
    # ellipsis to . . . 
    $color_param =~ s{\x85}{ . . . }xmsg;
    # tidy up rgb(a,b,c)
    $color_param =~ s{ [(] ([^)]*) [)] }{'(' . squish($1) . ')'}xmsge;
    my %colors = get_colors($uuid);
    my @new_colors = split ' ', $color_param;
    my %schemes;
    my $sch = $uuid_color_schemes_for{$uuid};
    if ($sch) {
        %schemes = %{ eval $sch };
    }

    my $single;
    if (@new_colors == 1) {
        $single = $new_colors[0];
    }
    if ($single
        && $single =~ m{\A ([a-z]) \z}xms
    ) {
        # a PreSet
        my $let = $1;
        my $colors9 = $uuid_colors_for{"preset $let"};
        if (! $colors9) {
            # doesn't exist - force it to be A
            $colors9 = $uuid_colors_for{"preset a"};
        }
        @colors{@names} = mqw($colors9);
    }
    elsif ($single
           && exists $schemes{$single}
    ) {
        # they're choosing one of their previously saved schemes
        @colors{@names} = mqw($schemes{$single});
    }
    else {
        # a NEW setting of colors
        #
        # validate the colors
        # TODO - limit it to 9 colors
        my @bad;
        for my $i (0 .. $#new_colors) {
            my $c = $new_colors[$i];
            if ($c eq '.') {
                # don't change this position
                $new_colors[$i] = $colors{$names[$i]};
            }
            elsif ($valid_color{$c}) {
                # ok
            }
            elsif ($c =~ m{\A [#][a-f0-9]{6} \z }xms) {
                # ok
            }
            elsif ($c =~ m{\A rgb[(](\d+),(\d+),(\d+)[)] \z}xmsi
                   && within($1) && within($2) && within($3)
            ) {
                # ok
            }
            elsif ($c =~ m{\A g ([1-9]) \z}xms) {
                my $x = 255*($1/10);
                $new_colors[$i] = sprintf "rgb(%d,%d,%d)", $x, $x, $x;
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
            $colors{$names[$i]} = $new_colors[$i];
        }
    }
    $uuid_colors_for{$uuid} = join ' ', @colors{@names};
    return '';
}

# returns a hash with 7 keys
sub get_colors {
    my ($uuid) = @_;
    my $s = $uuid_colors_for{$uuid};
    if ($s) {
        my @col = mqw($s);
        my %colors;
        for my $i (0 .. 8) {
            $colors{$names[$i]} = $col[$i];
        }
        return %colors;
    }
    else {
        return (
            center_hex  => 'gold',
            center_text => 'black',
            donut_hex   => 'lightgray',
            donut_text  => 'black',
            background  => 'white',
            letter      => 'black',
            alink       => 'blue',
            bg_input    => 'white',
            bg_text     => 'black',
        );
    }
}

sub save_colors {
    my ($uuid, $name) = @_;
    if ($name =~ m{\A preset\s([a-z]) \z}xms) {
        my $let = $1;
        $uuid_colors_for{$name} = $uuid_colors_for{$uuid};
        return "Colors saved in PreSet \U$let.";
    }
    elsif ($valid_color{$name}) {
        # what about g1-9?
        return "Sorry, you cannot save your color scheme to one of the 140 standard HTML Web Color names.";
    }
    elsif ($name =~ m{\A [a-z] \z}xms) {
        return "Sorry, your color scheme name cannot be just 1 letter.";
    }
    else {
        my $s = $uuid_color_schemes_for{$uuid};
        my %schemes;
        if ($s) {
            %schemes = %{ eval $s };
        }
        # update or add:
        $schemes{$name} = $uuid_colors_for{$uuid}; 
        $uuid_color_schemes_for{$uuid} = Dumper(\%schemes);
        return "Your color scheme was saved to \U$name.\n";
    }
}

sub color_schemes {
    my ($uuid) = @_;
    my $s = $uuid_color_schemes_for{$uuid};
    my @schemes;
    if ($s) {
        @schemes = keys %{ eval $s; };
    }
    if (@schemes) {
        return "Your color schemes: "
             . join(', ', map { uc } @schemes);
    }
    return "You have no saved color schemes.";
}

sub del_scheme {
    my ($uuid, $scheme) = @_;
    my %schemes;
    my $s = $uuid_color_schemes_for{$uuid};
    if ($s) {
        %schemes = %{ eval $s };
    }
    delete $schemes{$scheme};
    $uuid_color_schemes_for{$uuid} = Dumper(\%schemes);
}

1;
