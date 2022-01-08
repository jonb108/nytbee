#!/usr/bin/perl
use strict;
use warnings;

=comment

ToDo:
DA should give clues PLUS all definitions from all dictionaries
D/DA word should not give clues - just definitions

I - show who has given hints for the NYT Puzzle

F and S - look in Community Puzzles as well...

XA - clear all and revert to today
    sure why not
D MONONYM - give dictionary definition not the clue
DA XY - give all dictionary definitions from all 3 dictionaries AND a clue if present
DA F4 - same as DA XY

saved games - with timestamp? and purge ones more than a month old

_will_ work on the phone but it's awkward.
most everyone has a laptop or desktop
so we won't try to have the 7 letters clickable/tappable

in hidden fields we store the minimum state we need:
    date, puzzle data from archive, found words
and we compute the rest - score, max_score, rankings, hint table
it is plenty fast

the usual web trick is to store the puzzle state
in a stateless environment... with hidden fields.

=cut

use CGI qw/
    :standard
/;
my $q = CGI->new();
print $q->header();
my %params = $q->Vars();

use BeeUtil qw/
    trim
    ip_id
/;

use DB_File;
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';
my %ip_date;
tie %ip_date, 'DB_File', 'ip_date.dbm';

# for NYT puzzles:
my %puzzle_has_clues;
tie %puzzle_has_clues, 'DB_File', 'nyt_puzzles_has_clues.dbm';

my $comm_dir = 'community_puzzles';
my ($seven, $center, @pangrams);
my @seven;
my @ok_words;
my %clue_for;
my %nyt_clues_for;
my $ip_id = ip_id();
my $log = 'http://logicalpoetry.com';

my $message = '';

use Date::Simple qw/
    today
    date
/;

sub my_today {
    my ($hour) = (localtime)[2];
    my $today = today();
    if ($hour < 3) {
        --$today;
    }
    return $today;
}

sub dash_date {
    my ($d8) = @_;
    if ($d8 =~ m{\A CP}xms) {
        return $d8;
    }
    my ($y, $m, $d) = $d8 =~ m{\A ..(..)(..)(..) \z}xms;
    return "$m-$d-$y";
}
# puzzle from which date?
# date from new_words/command field (nr, n11 n12/23/18)
# date from hidden field (date)
# today
#
my $cmd = lc $params{new_words};
    # $cmd is all in lower case
    # even though it looks like we are typing upper case...
    #
$cmd = trim($cmd);

my $first = date('5/29/18');
my $date;
my $today = my_today();
my $new_puzzle = 0;

# Remove a set of current puzzles.
if (my ($nums) = $cmd =~ m{\A x \s* ([\d,\s-]+) \z}xms) {
    $nums =~ s{\s*-\s*}{-}xms;
    my @terms = split /[,\s]+/, $nums;
    my @nums;
    for my $t (@terms) {
        if ($t =~ m{\A \d+ \z}xms) {
            push @nums, $t;
        }
        elsif (my ($start, $end) = $t =~ m{(\d+)-(\d+)}xms) {
            if ($start > $end) {
                $message = "Illegal range: $start-$end";
                $cmd = '';
            }
            else {
                push @nums, $start .. $end;
            }
        }
        else {
            $message = "Illegal puzzle numbers: $nums";
            $cmd = '';
        }
    }
    if ($cmd) {
        my @puzzles = my_puzzles();
        my $npuzzles = @puzzles;
        for my $n (@nums) {
            if ($n > $npuzzles) {
                $message = "$n: There are only $npuzzles current puzzles";
                $cmd = '';
            }
        }
    }
    if ($cmd) {
        # it's weird - our puzzles are not in an array
        # we need to get them each time...
        # perhaps we can do it at the top and use it...???
        #
        # @nums are valid puzzle numbers (base 1)
        my @puzzles = my_puzzles();
        for my $n (@nums) {
            # the key is complicated!
            my $key = $ip_id . ' ' . $puzzles[$n-1][0];
            delete $ip_date{$key};
        }
        @puzzles = my_puzzles();
        if (! @puzzles) {
            $cmd = 't';
        }
        else {
            PUZ:
            for my $p (@puzzles) {
                if ($p->[0] eq $params{date}) {
                    # we haven't deleted the current puzzle
                    # so leave it
                    $cmd = '';
                    last PUZ;
                }
            }
            if ($cmd) {
                # we deleted the current puzzle
                # so move to the last one
                # we know we have at least one.
                $cmd = 'p' . scalar(@puzzles);
            }
        }
    }
}
if (my ($puz_num) = $cmd =~ m{\A p \s* (\d+) \z}xms) {
    my @puzzles = my_puzzles();
    if ($puz_num > @puzzles) {
        $message = "Not that many puzzles";
        $cmd = '';
    }
    my $puz_id = $puzzles[$puz_num-1][0];
    if ($puz_id =~ m{\A \d}xms) {
        $cmd = "n$puz_id";
    }
    else {
        # CP\d+
        # but we need lower case cp
        # since we have
        $cmd = lc $puz_id;
    }
}
if ($cmd =~ m{\A n \s* r \z}xms) {
    # random date since $first
    my $ndays = $today - $first + 1;
    $date = $first + int(rand $ndays);
    $date = $date->as_d8();
    $params{found_words} = '';
    $new_puzzle = 1;
    $cmd = '';
}
elsif (my ($cp_num) = $cmd =~ m{\A c \s* p \s* (\d+) \z}xms) {
    my $fname = "$comm_dir/$cp_num.txt";
    if (! -f $fname) {
        $message = "$cp_num: No such Community Puzzle";
        $cmd = '';
    }
    else {
        $date = "CP$cp_num";
        $new_puzzle = 1;
        $cmd = '';
    }
}
elsif ($cmd eq 't') {
    $date = $today->as_d8();
    $params{found_words} = '';
    $new_puzzle = 1;
    $cmd = '';
}
elsif ($cmd =~ m{\A n \s* (\d.*) \z}xms) {
    $date = date($1);
    if ($date) {
        # it is a valid date but is it in the range?
        if ($first <= $date && $date <= today()) {
            $date = $date->as_d8();
            $params{found_words} = '';
            $new_puzzle = 1;
            $cmd = '';
        }
        else {
            $date = '';
        }
    }
}
if (! $date) {
    $date = $params{date};      # hidden field
}
if (! $date) {
    # today
    $date = my_today()->as_d8();
    $new_puzzle = 1;
}
my $show_date;
my $cp_href;

# we have a valid date. either d8 format or CP#
# if d8 get the puzzle data
if ($date =~ m{\A\d}xms) {
    # NYT Puzzles
    $show_date = date($date)->format("%B %e, %Y");
    my $puzzle = $puzzle{$date};

    my ($s, $t) = split /[|]/, $puzzle;
    ($seven, $center, @pangrams) = split ' ', $s;
    @seven = split //, $seven;
    @ok_words = split ' ', $t;
    if ($puzzle_has_clues{$date}) {
        my $href = eval `curl -skL $log/cgi-bin/nytbee_get_clues/$date`;
        %nyt_clues_for = %$href;
    }
}
else {
    # Community Puzzles
    # $date is CP\d+
    my ($n) = $date =~ m{(\d+)}xms;
    my $fname = "$comm_dir/$n.txt";
    $cp_href = do $fname;
    $seven = $cp_href->{seven};
    @seven = split //, $seven;
    $center = $cp_href->{center};
    @pangrams = split ' ', $cp_href->{pangrams};
    @ok_words = split ' ', $cp_href->{words};
    %clue_for = $cp_href->{clues} =~ m{([a-z]+)\^([^~]+)~}xmsg;
    $show_date = $date;
}
my $nwords = @ok_words;
my $npangrams = @pangrams;

my %is_pangram = map { $_ => 1 } @pangrams;
my %is_ok_word = map { $_ => 1 } @ok_words;
my @six = map { uc }
          grep { $_ ne $center }
          @seven;

if (! $cmd && ! $params{has_message}) {
    # scramble
    my @new;
    push @new, splice @six, rand @six, 1 while @six;
    @six = @new;
}

sub word_score {
    my ($w) = @_;
    my $l = length $w;
    return ($l == 4? 1: $l) + ($is_pangram{$w}? 7: 0);
}
my $max_score = 0;
for my $w (@ok_words) {
    $max_score += word_score($w);
}
my @ranks = (
    { name => 'Beginner',   pct =>   0, value => 0 },
    { name => 'Good Start', pct =>   2, value => int(.02*$max_score + 0.5) },
    { name => 'Moving Up',  pct =>   5, value => int(.05*$max_score + 0.5) },
    { name => 'Good',       pct =>   9, value => int(.08*$max_score + 0.5) },
    { name => 'Solid',      pct =>  15, value => int(.15*$max_score + 0.5) },
    { name => 'Nice',       pct =>  25, value => int(.25*$max_score + 0.5) },
    { name => 'Great',      pct =>  40, value => int(.40*$max_score + 0.5) },
    { name => 'Amazing',    pct =>  50, value => int(.50*$max_score + 0.5) },
    { name => 'Genius',     pct =>  70, value => int(.70*$max_score + 0.5) },
    { name => 'Queen Bee',  pct => 100, value => $max_score },
);

my (@found, $nhints, $ht_chosen, $tl_chosen);
my $key = "$ip_id $date";
if (exists $ip_date{$key}) {
    my ($d8, $ap, $rnk);
    ($d8, $nhints, $ap, $ht_chosen, $tl_chosen, $rnk, @found)
        = split ' ', $ip_date{$key};
}
else {
    $nhints    = $new_puzzle? 0: $params{nhints} || 0;    # from before
    $ht_chosen = $new_puzzle? 0: $params{ht_chosen};
    $tl_chosen = $new_puzzle? 0: $params{tl_chosen};
    @found     = $new_puzzle? (): split ' ', $params{found_words};
}

sub my_puzzles {
    return
    map {
        [
            (split ' ', $_)[2],
            (split ' ', $ip_date{$_})[2, 5]
        ]
    }
    sort
    grep { index($_, $ip_id) == 0 }
    keys %ip_date;
}

my %is_found = map { $_ => 1 } @found;

my $score;
my $rank_name;
my $rank;

sub compute_score_and_rank {
    $score = 0;
    for my $w (@found) {
        $score += word_score($w);
    }
    RANK:
    for my $r (0 .. $#ranks-1) {
        # note that $#ranks is Queen Bee == 9
        if (   $score >= $ranks[$r]->{value}
            && $score <  $ranks[$r+1]->{value}
        ) {
            $rank_name = $ranks[$r]->{name};
            $rank = $r;
            last RANK;
        }
    }
    # special case:
    if ($score >= $max_score) {
        $rank = 9;
        $rank_name = 'Queen Bee';
    }
}

# to be ready for the 'r' command
compute_score_and_rank();

# if no definition
# drop a final d or a final ed
# or ly?????
# and mark it as such
# the online dictionaries often give many different
# definitions - let's just show 3 at the most.
# that's enough.  or maybe just 1?
# or all if Dcmd.
sub define {
    my ($word, $Dcmd, $dont_tally_hints, $dont_mask) = @_;

    # a Community Puzzle clue
    if (exists $clue_for{$word}) {
        if (! $dont_tally_hints) {
            $nhints += 3;
        }
        return "<li style='list-style-type: circle'>$clue_for{$word}</li>";
    }
    # community contributed NYT Bee Puzzle clues
    if (exists $nyt_clues_for{$word}) {
        my $s = '';
        for my $cl (@{$nyt_clues_for{$word}}) {
            $s .= "<li style='list-style-type: circle'>$cl</li>\n";
        }
        if (! $dont_tally_hints) {
            # just one word, perhaps several hints for that word
            $nhints += 3;
        }
        return $s;
    }

    my ($html, @defs);

    # merriam-webster
    $html = `curl -skL https://www.merriam-webster.com/dictionary/$word`;
    # to catch an adequate definition for 'bought':
    @defs = $html =~  m{meaning\s+of\s+$word\s+is\s+(.*?)[.]\s+How\s+to}xmsi;
    push @defs, $html =~ m{dtText(.*?)\n}xmsg;
    if ($Dcmd || ! @defs) {
        # some definitions (like 'from') use a different format
        # no clue why
        push @defs, ($html =~ m{"unText">(.*?)</span>}xmsg);
    }
    for my $def (@defs) {
        $def = trim($def);
        $def =~ s{<[^>]*>}{}xmsg;   # strip tags
        $def =~ s{.*:\s+}{}xms;
    }
    if (! @defs) {
        # collins
        $html = `curl -skL https://www.lexico.com/en/definition/$word`;
        @defs = $html =~ m{Lexical\s+data\s+-\s+en-us">(.*?)</span>}xmsg;
    }
    my $stars = '*' x length $word;
    # sometimes the definition is duplicated so ...
    my %seen;
    my @tidied_defs;
    DEF:
    for my $d (@defs) {
        $d =~ s{<[^>]*>}{}xmsg; # excise any tags
        $d =~ s{[^[:print:]]}{}xmsg; # excise any non-printing chars
        $d =~ s{$word}{$stars}xmsgi unless $dont_mask;    # hide the word
        if ($seen{$d}++) {
            next DEF;
        }
        push @tidied_defs, $d;
    }
    if (! $Dcmd) {
        @tidied_defs = splice @tidied_defs, 0, 3;
    }
    if (@tidied_defs && ! $dont_tally_hints) {
        $nhints += 3;
    }
    return join '',
           map {
               "<li>$_</li>\n";
           }
           @tidied_defs;
}

sub reveal {
    my ($word, $nlets, $beg_end) = @_;

    my $dash = ' &ndash;';
    my $lw = length $word;
    if ($nlets >= $lw) {
        # silently ignore
        return;
    }
    $nhints += 2;
    if (! $beg_end) {
        return uc(substr($word, 0, $nlets))
               . ($dash x ($lw-$nlets))
               . "<br>"
               ;
    }
    my $c2 = int($nlets/2);
    my $c1 = $nlets - $c2;
    my $cu = $lw - $nlets;
    return uc(substr($word, 0, $c1))
           . ($dash x $cu)
           . uc(substr($word, $lw-$c2))
           . "<br>"
           ;
}

sub get_words {
    my ($s, $l) = @_;
    return grep {
               ! $is_found{$_}
               &&
               ($l? substr($_, 0, 1) eq $s
                   && length == $l
              :    substr($_, 0, 2) eq $s)
           }
           @ok_words;
}

# do we have a reveal command?
my $reveal = "";
if ($cmd eq 'ht') {
    if (! $ht_chosen) {
        $ht_chosen = 1;
        $nhints += 10;
    }
    $cmd = '';
}
elsif ($cmd eq 'tl') {
    if (! $tl_chosen) {
        $tl_chosen = 1;
        $nhints += 5;
    }
    $cmd = '';
}
elsif (my ($ev, $nlets, $term)
    = $cmd =~ m{
        \A ([ev])\s*(\d+)\s*(p|[a-z]\s*\d+|[a-z]\s*[a-z]) \z
      }xms
) {
    my $end = $ev eq 'e';
    if ($term eq 'p') {
        for my $p (grep { ! $is_found{$_} } @pangrams) {
            $message .= reveal($p, $nlets, $end);
        }
    }
    elsif (my ($first, $len) = $term =~ m{\A ([a-z])\s*(\d+)}xms) {
        if ($nlets == 1) {
            # silently gnore
        }
        else {
            for my $w (get_words($first, $len)) {
                $message .= reveal($w, $nlets, $end);
            }
        }
    }
    else {
        # $term is two letters
        if ($nlets == 1 || (! $end && $nlets == 2)) {
            # silently ignore
        }
        else {
            $term =~ s{\s}{}xmsg;       # if v2 a b instead of v2ab
            for my $w (get_words($term)) {
                $message .= reveal($w, $nlets, $end);
            }
        }
    }
    if ($message) {
        $message = "\U$cmd\E:<ul>$message</ul>";
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A r\s* (%?) \z}xms) {
    my $percent = $1;
    my $rows = '';
    for my $r (0 .. 9) {
        my $cols = td($ranks[$r]->{name});
        if ($percent) {
            $cols .= td("$ranks[$r]->{pct}%");
        }
        $cols .= td('&nbsp;' . $ranks[$r]->{value});
        if ($rank == $r) {
            my $more = '';
            if ($rank != 9) {
                $more = ' '
                      . ($ranks[$r+1]->{value} - $score)
                      . ' more'
                      ;
                if ($rank == 8) {
                    my $m = @ok_words - @found;
                    my $pl = $m == 1? '': 's';
                    $more .= ", $m more word$pl";
                }
            }
            $cols .= td("*$more");
        }
        $rows .= Tr($cols);
    }
    $message = ul(table({ cellpadding => 4}, $rows));
    $cmd = '';
}
elsif (   $cmd =~ m{\A (d) \s*  (p|[a-z]\d+|[a-z][a-z]) \z}xms
       || $cmd =~ m{\A (da) \s+ (p|[a-z]\d+|[a-z][a-z]) \z}xms
) {
    my $Dcmd = $1 eq 'da';
    my $term = $2;
    my $line = "&mdash;" x 4;
    if ($term eq 'p') {
        for my $p (grep { !$is_found{$_} } @pangrams) {
            $message .= "<ul>"
                     .  define($p, $Dcmd, 0)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "Pangrams:$message";
        }
        $cmd = '';
    }
    elsif ($term =~ m{([a-z])(\d+)}xms) {
        my $let = $1;
        my $len = $2;
        $message = '';
        for my $w (get_words($let, $len)) {
            $message .= "<ul>"
                     .  define($w, $Dcmd, 0)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "\U$term\E:<br>$message";
        }
        $cmd = '';
    }
    elsif ($term =~ m{([a-z][a-z])}xms) {
        my $lets = $1;
        $message = '';
        for my $w (get_words($lets)) {
            $message .= "<ul>"
                     .  define($w, $Dcmd, 0)
                     .  "</ul>"
                     .  "--";
                     ;
        }
        $message =~ s{--\z}{}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "\U$term\E:<br>$message";
        }
        $cmd = '';
    }
}
elsif ($cmd =~ m{\A (d|da) \s+ ([a-z]+) \z}xms) {
    my $Dcmd = $1 eq 'da';
    my $word = $2;
    $message = "\U$word:"
             . "<ul>"
             . define($word, $Dcmd, 1, 1)
             . "</ul><p>"
             ;
    $cmd = '';
}
elsif ($cmd =~ m{\A g \s+ y \z}xms) {
    my @words =
             map {
                 $is_pangram{lc $_}? color_pg($_): $_
             }
             map { ucfirst }
             grep { !$is_found{$_} }
             @ok_words;
    if (@words) {
        $nhints += @words * 5;
        $message = "<p class=mess>@words";
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A c \s+ y \z}xms) {
    @found = ();
    %is_found = ();
    $nhints = 0;
    $ht_chosen = 0;
    $tl_chosen = 0;
    $cmd = '';
}
elsif ($cmd eq 'sc') {
    my $rows = '';
    my $tot = 0;
    my $space = '&nbsp;' x 1;
    for my $w (@found) {
        my $sc = word_score($w);
        $tot += $sc;
        my $s = ucfirst $w;
        if ($is_pangram{$w}) {
            $s = color_pg($s);
        }
        $rows .= Tr(td($s), td($space.$sc), td($space.$space.$tot));
    }
    $message = table({ cellpadding => 2 }, $rows);
    my $more = @ok_words - @found;
    my $pl = $more == 1? '': 's';
    $message .= "<p> $more more word$pl to find";
    $cmd = '';
}
elsif ($cmd eq 'l') {
    my @puzzles = my_puzzles();
    my $n = 1;
    for my $p (@puzzles) {
        my $cur = $p->[0] eq $date? '*': '';
        my $pg  = $p->[1]? '&nbsp;&nbsp;p': '';
        $message .= Tr(
                        td($n) . td($cur)
                      . td({ style => 'text-align: left' }, dash_date($p->[0]))
                      . td({ -style => 'text-align: left'},
                           $ranks[$p->[2]]->{name})
                      . td($pg)
                    );
        ++$n;
    }
    $message = table({ cellpadding => 4}, $message);
    $cmd = '';
}
elsif ($cmd eq 'f') {
    # look for same 7
    my @dates;
    while (my ($dt, $puz) = each %puzzle) {
        if (substr($puz, 0, 7) eq $seven) {
            push @dates, $dt . uc substr($puz, 8, 1);
        }
    }
    $message = join '',
               map {
                  my ($dt, $y, $m, $d, $c) =  m{
                      \A (.. (..)(..)(..))(.) \z
                  }xms;
                  "$m-$d-$y $c"
                  . ($dt eq $date? ' *': '')
                  . "<br>\n";
              }
              sort
              @dates
              ;
    $cmd = '';
}
elsif ($cmd =~ m{\A s \s+ ([/a-z]+) \s* \z}xms) {
    # search the archive for the word (or a regex - undocumented).
    # we're searching everything after the |
    my $word = $1;
    my $regex = $word;
    if ($regex !~ s{\A /}{}xms) {
        $regex = "\\b$regex\\b";
    }
    my @dates;
    while (my ($dt, $puz) = each %puzzle) {
        $puz =~ s{\A [^|]* [|]}{}xms;
        if ($puz =~ m{$regex}xms) {
            push @dates, $dt;
        }
    }
    $message = join '',
               map {
                   m{\A ..(..)(..)(..)}xms;
                   "$2-$3-$1<br>";
               }
               sort
               @dates
               ;
    if ($message) {
        $message = "\U$word\E:<br>$message";
    }
    $cmd = '';
}

# now to prepare the display the words we have found
# some subset, some order
my $order = 0;
my $prefix = '';
my $limit = 0;
my @words_found;
if ($cmd eq 'w') {
    @words_found = @found;
    $cmd = '';
}
elsif ($cmd =~ m{\A w \s* ([<>]) \s* (\d*)\z}xms) {
    $order = $1 eq '>'? 1: -1;
    $limit = $2;
    # by increasing or decreasing length
    # time for a schwarzian transform!
    @words_found = grep {
                       $limit? ($order == 1? length($_) > $limit
                               :             length($_) < $limit)
                      :        1
                   }
                   map {
                       $_->[1]
                   }
                   sort {
                       $a->[0] <=> $b->[0]
                       ||
                       $a->[1] cmp $b->[1]
                   }
                   map {
                       [ $order * length, $_ ]
                   }
                   @found;
    $cmd = '';
}
elsif ($cmd =~ m{\A w \s* (\d+) \z}xms) {
    my $len = $1;    # words of a _given_ length
    $prefix = 1;     # set this so that if there are no
                     # words of length $len we will display
                     # nothing instead of the whole list
    if ($len < 4) {
        # makes no sense given all words are >= 4
        # silently ignore this
        @words_found = sort @found;
    }
    else {
        @words_found = grep {
                           length == $len
                       }
                       sort
                       @found;
    }
    $cmd = '';
}
# must have space for W prefix command
elsif ($cmd =~ m{\A w \s+ ([a-z]+)}xms) {
    $prefix = $1;
    @words_found = grep {
                       m{\A $prefix}xms
                   }
                   sort
                   @found;
    $cmd = '';
}

# so we have dealt with the various commands.
# except for 1 and 2, that is.
# what new words might we have instead?
my @new_words;
if ($cmd !~ m{\A [12] \z}xms) {
    @new_words = map {
                     lc
                 }
                 split ' ', $cmd;
}
my $not_okay_words;
my %is_new_word;
sub check_word {
    my ($w) = @_;
    if (length $w < 4) {
        return 'too short';
    }
    if (index($w, $center) < 0) {
        return "does not contain: <span class=red1>\U$center</span>";
    }
    for my $c (split //, $w) {
        if (index($seven, $c) < 0) {
            return "\U$c\E is not in \U$seven";
        }
    }
    if (! exists $is_ok_word{$w}) {
        return "not in word list";
    }
    return '';
}
for my $w (@new_words) {
    if (my $mess = check_word($w)) {
        $not_okay_words .= "<span class=not_okay>"
                        .  uc($w)
                        .  "</span>: $mess<br>";
    }
    else {
        if (! $is_found{$w}) {
            push @found, $w;
            $is_found{$w} = 1;
        }
        # words that were found before will
        # be highlighted in the list.  no error.
        $is_new_word{$w} = 1;
    }
}

# now that we have added the new words...
compute_score_and_rank();

if (! $prefix && ! $limit && ! @words_found) {
    # the default when there are no restrictions
    @words_found = sort @found;
}

if ($not_okay_words) {
    $message = <<"EOH";
<ul>
$not_okay_words
</ul>
EOH
}

sub color_pg {
    my ($pg) = @_;
    my $class = length($pg) == 7? 'purple': 'green';
    return "<span class=$class>$pg</span>";
}

# time to display the words we have found
# in various orders and various subsets
# which were set above.
# perhaps have a break between words of diff lengths
# in case we had w < or w >.
my $found_words = '';
my $prev_length = 0;
for my $w (@words_found) {
    my $lw = length($w);
    my $uw = ucfirst $w;
    if ($is_pangram{$w}) {
        $w = color_pg($uw);
    }
    elsif ($is_new_word{$w}) {
        $w = "<span class=new_word>$uw</span>";
    }
    else {
        $w = $uw;
    }
    my $pre = ! $prev_length               ? ($order? "$lw: ": '')
             :$order && $lw != $prev_length? "<br>$lw: "
             :                               ' '
             ;
    $found_words .= "$pre$w";
    $prev_length = $lw;
}
if (@found && @words_found == @found && ! $order) {
    my $nwords = @found;
    $found_words .= " <span class=gray>$nwords</span>";
}

my %sums;
my %two_lets;
my $max_len = 0;
WORD:
for my $w (@ok_words) {
    my $l = length($w);
    if ($max_len < $l) {
        $max_len = $l;
    }
    if ($is_found{$w}) {
        # skip it
        next WORD;
    }
    my $c1 = substr($w, 0, 1);
    my $c2 = substr($w, 0, 2);
    ++$sums{$c1}{$l};
    ++$two_lets{$c2};
}

# now that #we have computed %sums and %two_lets
# perhaps $cmd was not words to add after all...
if ($cmd eq '1') {
    # find a random non-zero entry in the hint table
    my @entries;
    for my $l (4 .. $max_len) {
        for my $c (sort @seven) {
            if ($sums{$c}{$l}) {
                push @entries, "\U$c$l-$sums{$c}{$l}";
            }
        }
    }
    if (@entries) {
        # not Queen Bee yet
        ++$nhints;
        $message = $entries[ rand @entries ];
    }
}
elsif ($cmd eq '2') {
    # random non-zero entry in %two_lets
    my @entries;
    for my $k (sort keys %two_lets) {
        if ($two_lets{$k}) {
            push @entries, "\U$k-$two_lets{$k}";
        }
    }
    if (@entries) {
        # not Queen Bee yet
        ++$nhints;
        $message = $entries[ rand @entries ];
    }
}

my $bingo = ", Bingo";
CHAR:
for my $c (@seven) {
    if (! exists $sums{$c}) {
        $bingo = '';
        last CHAR;
    }
}
my $perfect = '';
my $nperfect = 0;
for my $p (keys %is_pangram) {
    if (length $p == 7) {
        ++$nperfect;
    }
}
if ($nperfect) {
    $perfect = " ($nperfect Perfect)"
}
if ($cmd eq 'i') {
    $message = "Words: $nwords, Points: $max_score, "
             . "Pangrams: $npangrams$perfect$bingo";
    if ($date =~ m{\A CP}xms) {
        my ($n) = $date =~ m{(\d+)}xms;
        my $created = date($cp_href->{created})->format("%B %e, %Y");
        my $s = "";
        for my $w (qw/ title name location contact /) {
            if (my $t = $cp_href->{$w}) {
                if ($w eq 'contact' && index($t, '@') >= 0) {
                    $t = "<a href='mailto:$t?"
                       . "subject=Community Puzzle #$n'>$t</a>";
                }
                $s .= "$t<br>";
            }
        }
        $message .= "<br>Community Puzzle #$n - $created<ul>$s</ul>";
    }
    $cmd = '';
}

# the hint table
my $hint_table = "";
if ($ht_chosen) {
    $hint_table = "<table cellpadding=2 border=0>\n";
    my $space = '&nbsp;' x 4;
    $hint_table .= "<tr><th>&nbsp;</th>";
    for my $l (4 .. $max_len) {
        $hint_table .= "<th>$space$l</th>";
    }
    $hint_table .= "<th>$space&nbsp;&Sigma;</th></tr>\n";
    my $tot = 0;
    for my $c (@seven) {
        $hint_table .= "<tr><th style='text-align: center'>\U$c\E</th>";
        my $sum = 0;
        for my $l (4 .. $max_len) {
            $hint_table .= "<td>"
                        .  ($sums{$c}{$l}?
                               "<span class=pointer"
                             . qq! onclick="define_ht('$c', $l);">!
                             . "$sums{$c}{$l}</span>"
                          : '&nbsp;-&nbsp;')
                        . "</td>";
            $sum += $sums{$c}{$l};
        }
        $hint_table .= "<th>$sum</th></tr>\n";
        $tot += $sum;
    }
    $hint_table .= "<tr><th style='text-align: right'>&Sigma;</th>";
    for my $l (4 .. $max_len) {
        my $sum = 0;
        for my $c (@seven) {
            $sum += $sums{$c}{$l};
        }
        $hint_table .= "<th>$sum</th>";
    }
    $hint_table .= "<th>$tot</th></tr>\n";
    $hint_table .= "</table>\n";
}

# two letter tallies
my $two_lets = '';
if ($tl_chosen) {
    my @two = grep {
                  $two_lets{$_}
              }
              sort
              keys %two_lets;
    TWO:
    for my $i (0 .. $#two) {
        if ($two_lets{$two[$i]} == 0) {
            next TWO;
        }
        $two_lets .= qq!<span class=pointer onclick="define_tl('$two[$i]');">\U$two[$i]-$two_lets{$two[$i]}</span>!;
        if ($i < $#two
            && substr($two[$i], 0, 1) ne substr($two[$i+1], 0, 1)
        ) {
            $two_lets .= "<p>";
        }
        else {
            $two_lets .= '&nbsp;&nbsp;';
        }
    }
}

# generate the rank colors and font sizes
my $rank_colors_fonts = "";
for my $i (0 .. 9) {
    my $color = 205-10*$i;
    my $size = 15+3*$i;
    $rank_colors_fonts .= <<"EOCSS";
.rank$i {
    font-size: ${size}pt;
    color: rgb(255, $color, 255);
}
EOCSS
}

my $image = '';
if (7 <= $rank && $rank <= 9) {
    my $name = lc $ranks[$rank]->{name};
    $name =~ s{\s.*}{}xms;  # for queen bee
    $image = "<img class=image_$name src=$log/pics/$name.jpg>";
}

my $disp_nhints = "";
if ($nhints) {
    $disp_nhints .= "<br>Hints: $nhints";
}

my $all_pangrams = 1;
PAN:
for my $p (@pangrams) {
    if (! $is_found{$p}) {
        $all_pangrams = 0;
        last PAN;
    }
}

# save IP address and state of the solve
$ip_date{$key} = $today->as_d8()
               . " $nhints $all_pangrams $ht_chosen $tl_chosen $rank @found";

my $has_message = 0;
if ($message) {
    $message .= '<p>';
    $has_message = 1;
}
# ???if nyt puzzle is current you should be able
# to create a community puzzle with this link...
my $create = $date =~ m{\A CP}xms? 'nytbee/mkpuz.html'
            :                      "cgi-bin/nytbee_mkclues?date=$date";

# now to display everything
# cgi-bin/style.css?

print <<"EOH";
<html>
<head>
<style>
.gray {
    color: lightgray;
}
.pointer {
    cursor: pointer;
}
.two_lets {
    margin-top: 0mm;
    margin-left: 5mm;
}
.help {
    margin-left: 1in;
}
.mess {
    width: 600px;
    word-spacing: 10px;
}
a {
    text-decoration: none;
    color: blue;
}
.pointer {
    cursor: pointer;
    color: blue;
}
.float-child1 {
    float: left;
    text-align: left;
}
.float-child2 {
    float: left;
    margin-left: .3in;
}
.float-child3 {
    float: left;
    margin-left: .2in;
    text-align: right;
}
.float-child4 {
    float: left;
    margin-left: .3in;
}
.float-child5 {
    float: left;
    margin-left: .1in;
}
.new_word {
    color: coral;
}
ul {
    margin-top: 0px;
    margin-bottom: 0px;
}
li {
    width: 600px;
}
td, th {
    text-align: right;
    font-size: 18pt;
    font-family: Arial;
}
.not_okay {
    color: red;
}
pre {
    font-size: 26pt;
}
body {
    margin-top: .3in;
    margin-left: .3in;
    font-size: 18pt;
    font-family: Arial;
}
input, .submit {
    font-size: 18pt;
    font-family: Arial;
}
.new_words {
    text-transform: uppercase;
}
.over {
    margin-left: 1in;
}
.red1, .red2 {
    color: red;
}
.red2 {
    font-weight: bold;
}
.green {
    color: green;
}
.purple {
    color: purple;
}
.found_words {
    width: 600px;
    word-spacing: 10px;
}
.submit {
    background: green;
    color: white;
}
.rank_name {
    margin-left: .5in;
}
$rank_colors_fonts
.rank9 {
    font-weight: bold;
}
.image_amazing {
    width: 75px;
}
.image_genius {
    width: 125px;
}
.image_queen {
    width: 175px;
}
</style>
<script>
function define_tl(two_let) {
    document.getElementById('new_words').value = 'D' + two_let;
    document.getElementById('main').submit();
}
function define_ht(c, n) {
    document.getElementById('new_words').value = 'D' + c + n;
    document.getElementById('main').submit();
}
</script>
</head>
<body>
<div class=float-container>
    <div class=float-child1>
        <a target=_blank href='https://www.nytimes.com/subscription'>NY Times</a> Spelling Bee<br>$show_date
    </div>
    <div class=float-child2>
         <img width=50 src=/pics/bee-logo.jpg>
    </div>
    <div class=float-child3>
        <span class=help><a target=_blank href='$log/nytbee/help.html#words'>Help</a><br><a target=_blank href='$log/$create'>Create</a></span>
    </div>
</div>
<br><br>
<form id=main name=form method=POST>
<input type=hidden name=date value='$date'>
<!-- not needed?? <input type=hidden name=puzzle value='dollar puzzle'> -->
<input type=hidden name=found_words value='@found'>
<input type=hidden name=nhints value=$nhints>
<input type=hidden name=ht_chosen value=$ht_chosen>
<input type=hidden name=tl_chosen value=$tl_chosen>
<input type=hidden name=has_message value=$has_message>
<pre>
     $six[0]   $six[1]
   $six[2]   <span class=red2>\U$center\E</span>   $six[3]
     $six[4]   $six[5]
</pre>
$message
<input class=new_words type=text size=40 id=new_words name=new_words><br>
</form>
<div class=found_words>
$found_words
</div>
<p>
Score: $score<span class='rank_name rank$rank'>$rank_name</span>
$image
$disp_nhints
<div class=float-container>
    <div class=float-child4>
        <div id=hint_table class=hint_table>
        $hint_table
        </div>
    </div>
    <div class=float-child5>
        <div id=two_lets class=two_lets>
        $two_lets
        </div>
    </div>
</div>
</body>
<script>document.form.new_words.focus();</script>
</html>
EOH