#!/usr/bin/env perl
use strict;
use warnings;

my $def = shift;
if ($def =~ m{
        r[>]        # <span class=letter>...
        (?:
            Common[ ]misspelling[ ]of
            |
            An[ ]obsolete[ ]variant[ ]of
            |
            An[ ]amended[ ]spelling[ ]of
            |
            An[ ]old[ ]spelling[ ]of
            |
            See
            |
            Same[ ]as
            |
            Of[ ]or[ ]pertaining[ ]to
            |
            Obsolete[ ]spelling[ ]of
            |
            Nonstandard[ ]spelling[ ]of
            |
            Alternative[ ]spelling[ ]of
            |
            An[ ]abbreviation[ ]of
            |
            An[ ]obsolete[ ]form[ ]of
            |
            Nonstandard[ ]spelling[ ]of 
            |
            Alternative[ ]form[ ]of
            |
            Of,[ ]relating[ ]to,[ ]derived[ ]from,[ ]or[ ]consisting[ ]of 
            |
            Simple[ ]past[ ]tense[ ]and[ ]past[ ]participle[ ]of
            |
            Plural[ ]form[ ]of
            |
            Plural[ ]of
            |
            Present[ ]participle[ ]of
        )
        [ ](no[ ]one|[\S-]+)

    }xms
) {
    my $w = $1;
    $w =~ s{[.,;!?<]+.*\z}{}xms;
    print $w;
}
