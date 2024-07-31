use strict;
use warnings;
package SvgHex;
use base 'Exporter';
our @EXPORT_OK = qw/
    svg_hex
/;

=comment

one hex arrangement:

  L
A   M
O   R
  D

M
139.3923,77.4782
160.8923,40.2391
203.8923,40.2391
225.3923,77.4782
203.8923,114.7173
160.8923,114.7173

R
139.3923,157.9564
160.8923,120.7173
203.8923,120.7173
225.3923,157.9564
203.8923,195.1955
160.8923,195.1955

225.3923,77.4782 M rightmost point
225.3923,157.9564 R rightmost point

203.8923,114.7173 M bottom right
203.8923,120.7173 R top right
203.8923,117.7173 between the two
    could find exact intersection point but ...

<polygon points='225.3923,77.4782, 225.3923,157.9564, 203.7923,117.7173'
         style='fill:black'
         BLANK
/>
if ($mobile) 
    BLANK => onclick="add_let(' ')"
else
    BLANK => 

Maybe the fill:black is not needed?

=cut

sub svg_hex {
    my ($mobile, $donut_mode) = @_;
    my $s = <<'EOH';
<!-- SEVEN HEXAGONS -->
<style>
.svglets {
    font-size: 18pt;
    font-family: Arial;
    font-weight: bold;
}
CURSOR
</style>
<svg
style="margin-left: .4in"
width="250.392304845413"
height="235.434554176385"
>
<polygonAL0
    id=center
    points="69.6962,117.7173,91.1962,80.4782,134.1962,80.4782,155.6962,117.7173,134.1962,154.9564,91.1962,154.9564"
    fill="CENTER_HEX"
    ></polygon>
<textAL0
    x="103.6962"
    y="125.8173"
    fill="CENTER_TEXT"
    class=svglets
>LET0</text>
<polygonAL1
    points="69.6962,37.2391,91.1962,-0.0000,134.1962,-0.0000,155.6962,37.2391,134.1962,74.4782,91.1962,74.4782"
    fill="DONUT_HEX"
    ></polygon>
<textAL1
    x="103.6962"
    y="45.3391"
    fill="DONUT_TEXT"
    class=svglets
>LET1</text>
<polygonAL2
    points="69.6962,198.1955,91.1962,160.9564,134.1962,160.9564,155.6962,198.1955,134.1962,235.4346,91.1962,235.4346"
    fill="DONUT_HEX"
    ></polygon>
<textAL2
    x="103.6962"
    y="206.2955"
    fill="DONUT_TEXT"
    class=svglets
>LET2</text>
<polygonAL3
    points="139.3923,157.9564,160.8923,120.7173,203.8923,120.7173,225.3923,157.9564,203.8923,195.1955,160.8923,195.1955"
    fill="DONUT_HEX"
    ></polygon>
<textAL3
    x="173.3923"
    y="166.0564"
    fill="DONUT_TEXT"
    class=svglets
>LET3</text>
<polygonAL4
    points="0.0000,77.4782,21.5000,40.2391,64.5000,40.2391,86.0000,77.4782,64.5000,114.7173,21.5000,114.7173"
    fill="DONUT_HEX"
    ></polygon>
<textAL4
    x="34.0000"
    y="85.5782"
    fill="DONUT_TEXT"
    class=svglets
>LET4</text>
<polygonAL5
    points="0.0000,157.9564,21.5000,120.7173,64.5000,120.7173,86.0000,157.9564,64.5000,195.1955,21.5000,195.1955"
    fill="DONUT_HEX"
    ></polygon>
<textAL5
    x="34.0000"
    y="166.0564"
    fill="DONUT_TEXT"
    class=svglets
>LET5</text>
<polygonAL6
    points="139.3923,77.4782,160.8923,40.2391,203.8923,40.2391,225.3923,77.4782,203.8923,114.7173,160.8923,114.7173"
    fill="DONUT_HEX"
    ></polygon>
<textAL6
    x="173.3923"
    y="85.5782"
    fill="DONUT_TEXT"
    class=svglets
>LET6</text>
BLANK
</svg>
<p>
EOH
    if ($mobile) {
        if ($donut_mode) {
            $s =~ s{AL0}{\nonclick="add_let('LET0'); blink_pink('center','CENTER_HEX');\n"}xms;
        }
        $s =~ s{AL(\d)}{\nonclick="add_let('LET$1')"\n}xmsg;
        $s =~ s<CURSOR><polygon, text { cursor: pointer; } >xms;
        $s =~ s{BLANK}{
<polygon id=pentagon
         points="225.3923,77.4782
                 250.3923,77.4782
                 250.3923,157.9564
                 225.3923,157.9564
                 203.0923,117.7173"
         onclick="add_let(' '); blink_pink('pentagon', 'BACKGROUND');"
         style='fill:BACKGROUND'
></polygon>
              }xms;
    }
    else {
        $s =~ s{AL(\d)}{}xmsg;
        $s =~ s<CURSOR><polygon, text { cursor: default; } >xms;
        $s =~ s{BLANK}{}xms;
    }
    return $s;
}

1;
