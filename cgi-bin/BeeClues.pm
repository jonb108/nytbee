use strict;
use warnings;
package BeeClues;
use base 'Exporter';
our @EXPORT_OK = qw/
    display_clues
/;

#
# all information should be provided to the
# display_clues subroutine.  It should not 
# need to look elsewhere.
#
# this is used by nytbee_mkclues2 and by nytbee_clues_by
#

sub _mklink {
    my ($f, $n, $s) = @_;

    my $space = '&nbsp;' x 3;
    if ($n == $f) {
        print "<span style='color: gray;'>$s</span>$space";
    }
    else {
        print "<span class=link onclick='set_format($n)'>$s</span>$space";
    }
}

sub display_clues {
    my (%param) = @_;
    for my $p (qw/
        first
        format
        show_date
        date
        person_id
        name
        clue_for_href
        was_found_href
    /) {
        if (! exists $param{$p}) {
            print "need a $p parameter to display_clues!<br>\n";
            return;
        }
    }
    my $first          = $param{first};
    my $format         = $param{format};
    my $show_date      = $param{show_date};
    my $date           = $param{date};
    my $person_id      = $param{person_id};
    my $name           = $param{name};
    my $clue_for_href  = $param{clue_for_href};
    my $was_found_href = $param{was_found_href};

    my @found      = keys %$was_found_href;
    my @clue_words = keys %$clue_for_href;
    my $all_found = 1;
    for my $w (@clue_words) {
        if (! exists $was_found_href->{$w}) {
            $all_found = 0;
        }
    }

    my $gray_level = 170;
    print <<"EOH";
<html>
<head>
<style>
body {
    margin: .5in;
    font-family: Arial;
    font-size: 18pt;
}
.clues {
    margin-top: 0mm;
}
.link {
    color: blue;
    cursor: pointer;
}
.gray {
    color: rgb($gray_level, $gray_level, $gray_level);
}
.info {
    display: normal;
}
</style>
<script>
function set_format(n) {
    document.getElementById('format').value = n;
    document.getElementById('main').submit();
}
function clear_text() {
    document.getElementById('info').style.display = 'none';
}
</script>
</head>
<body>
<form id=main method=POST action=/cgi-bin/nytbee_clues_by>
<input type=hidden name=first value=$first>
<input type=hidden name=date value=$date>
<input type=hidden name=name value='$name'>
<input type=hidden name=person_id value='$person_id'>
<input type=hidden name=found value='@found'>
<input type=hidden name=format id=format value=1>
</form>

EOH
    print <<'EOH';
<div id=info>
Alternate formats:
EOH
    _mklink($format, 1, "AB-x");
    _mklink($format, 2, "AB(x)");
    _mklink($format, 3, "ABx");
    _mklink($format, 4, "A-x");
    _mklink($format, 5, "A");
    print "&nbsp;&nbsp;<span class=link onclick='clear_text();'>Ok</span>";
    if ($first) {
        print <<"EOH";
<p>
The text below can be copy/pasted into the HiveMind forum.<br>
This window can then be closed.
<p>
EOH
    }
    print <<"EOH";
</div>
<h3>Clues for $show_date by $name</h3>
EOH
    my $prev_l1 = '';
    my $prev_l2 = '';
    for my $w (sort @clue_words) {
        my $class = !$all_found && $was_found_href->{$w}? 'gray': 'black';
        my $lw = length($w);
        my $l1 = uc substr($w, 0, 1);
        my $l2 = uc substr($w, 0, 2);
        if ($format == 3) {
            print "<span class=$class>";
        }
        if (($format == 4 || $format == 5) && $prev_l1 ne $l1) {
            print "<p>$l1<br>\n";
            $prev_l1 = $l1;
        }
        if ($format <= 3 && $prev_l2 ne $l2) {
            if ($format == 3) {
                if ($prev_l2) {
                    print "<br>";
                }
            }
            else {
                if ($prev_l2) {
                    print "</div><br>\n";
                }
                print "$l2<div class=clues>";
            }
        }
        if ($format == 3) {
            print "$l2$lw - ";
        }
        if ($format <= 2 || $format == 4 || $format == 5) {
            print "<span class=$class>";
        }
        if ($format == 4 || $format == 5) {
            print "&bull; ";
        }
        if ($format == 1 || $format == 2) {
            print '&nbsp;' x 3;
        }
        print ucfirst($clue_for_href->{$w});
        if ($format == 1 || $format == 4) {
            print " - $lw";
        }
        elsif ($format == 2) {
            print " ($lw) ";
        }
        if ($was_found_href->{$w}) {
            if ($format != 2) {
                print " = ";
            }
            print uc $w;
        }
        print "</span><br>\n";
        $prev_l2 = $l2;
    }
    print <<'EOH';
</body>
</html>
EOH
}

1;
