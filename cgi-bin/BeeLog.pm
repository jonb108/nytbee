use strict;
use warnings;
#
# open_log is used by:
#     nytbee_log.pl
#     nytbee_cw.pl
#     nytbee_activity.pl
#     nytbee_top.pl
#     nytbee_bbx.pl
#
package BeeLog;

use base 'Exporter';
our @EXPORT_OK = qw/
    open_log
/;

sub open_log {
    my ($date) = @_;
    my $in;
    if (-f "beelog/$date.gz") {
        open $in, '-|', "/usr/bin/zcat beelog/$date.gz"
            or die "cannot open zcat beelog/$date.gz: $!\n";
    }
    else {
        open $in, '<', "beelog/$date"
            or die "cannot open beelog/$date: $!\n";
    }
    return $in;
}

1;
