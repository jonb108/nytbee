use strict;
use warnings;
package BeeColor;
use base 'Exporter';
our @EXPORT_OK = qw/
    get_colors
    set_colors
/;
use BeeDBM qw/
    %uuid_colors_for
/;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

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
    # . to ' . ' so we don't have to insert spaces between dots
    $color_param =~ s{[.]}{ . }xmsg;
    # ellipsis to . . . 
    $color_param =~ s{\x85}{ . . . }xmsg;
    # tidy up rgb(a,b,c)
    $color_param =~ s{ [(] ([^)]*) [)] }{'(' . squish($1) . ')'}xmsge;
    my %colors = get_colors($uuid);
    my @new_colors = split ' ', $color_param;
    if (@new_colors == 1 && $new_colors[0] eq 'a') {
        # standard colors
        $colors{center_hex} = 'gold';
        $colors{center_text} = 'black';
        $colors{donut_hex} = '#e7e7e7';
        $colors{donut_text} = 'black';
        $colors{background} = 'white';
        $colors{letter} = 'black';
        $colors{alink} = 'blue';
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'b') {
        $colors{center_hex} = 'cornflowerblue';
        $colors{center_text} = 'midnightblue';
        $colors{donut_hex} = 'lavender';
        $colors{donut_text} = 'mediumblue';
        $colors{background} = 'lightblue';
        $colors{letter} = 'rgb(153,153,153)';
        $colors{alink} = 'cornflowerblue';
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'c') {
        $colors{center_hex} = 'firebrick';
        $colors{center_text} = 'hotpink';
        $colors{donut_hex} = 'salmon';
        $colors{donut_text} = 'darkred';
        $colors{background} = 'honeydew';
        $colors{letter} = 'rgb(153,153,153)';
        $colors{alink} = 'darkgreen';
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'd') {
        # dark mode standard colors
        $colors{center_hex} = 'gold';
        $colors{center_text} = 'black';
        $colors{donut_hex} = '#e7e7e7';
        $colors{donut_text} = 'black';
        $colors{background} = 'black';
        $colors{letter} = 'white';
        $colors{alink} = 'skyblue';
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'e') {
        # dark mode standard colors
        $colors{center_hex} = 'rgb(204,204,204)';
        $colors{center_text} = 'black';
        $colors{donut_hex} = 'rgb(178,178,178)';
        $colors{donut_text} = 'rgb(127,127,127)';
        $colors{background} = 'ivory';
        $colors{letter} = 'rgb(153,153,153)';
        $colors{alink} = 'olive';
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'f') {
        # Lilac Spring - from Morgan
        $colors{center_hex} = 'teal';
        $colors{center_text} = 'white';
        $colors{donut_hex} = 'plum';
        $colors{donut_text} = 'black';
        $colors{background} = 'seashell';
        $colors{letter} = 'black';
        $colors{alink} = 'navy';
    }
    elsif (@new_colors == 1 && $new_colors[0] eq 'g') {
        # Green - from Morgan
        $colors{center_hex} = 'darkgreen';
        $colors{center_text} = 'white';
        $colors{donut_hex} = 'darkseagreen';
        $colors{donut_text} = 'black';
        $colors{background} = 'honeydew';
        $colors{letter} = 'black';
        $colors{alink} = 'darkgoldenrod';
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
                # don't change this position
                $new_colors[$i] = $colors{$name[$i]};
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
