#!/usr/bin/perl
use strict;
use warnings;

=comment

what if i want a specific word to appear in a puzzle?
what pangramic word would make that possible?

pwords.txt
fourminus.txt - eliminate words with > 7 unique letters
    minus pwords.txt - which (along with other files) is updated nightly...

for an NYT Puzzle with clues
    authors are listed, click to see.
    if multiple authors add an All to see them all together
    test with different browsers, on cell.
    same idea as definitions - just grouped
    differently - and for all words
    enter multiple people's clues

Art is about "drawing the line".
    we're getting very close to the end.
    so perhaps put your new ideas in a
    section called "Future Plans?"
    when are we done?  when adding anything else
    spoils what is already there.
    or when explaining the new thing is simply
    too complicated and would put off people
    from trying it in the first place!

given a word find pangramic words that can
    create a puzzle with that word as
    part of the okay words.

find beta testers - friends and the hivemind
should it be labeled NYT Bee, ToBee, or what?

need new images for help.html since I 
resized the letters for hive 2, 3.
DRY for cycle clues
expand advantages, add clues in .html

<script>
several functions that
may not be used - make them conditional
</script>

make more additions to js/

divide styles into two - static and dynamic
    static can be cached the browser
    cgi_style.css is a start
scripts, too

Fantasy and Future ideas:

when a person creates a set of clues
    they set the format - one or two letters, length or not
        and whether the viewer can change it...

a way to restrict what hints/clues you can get.
    like no V, E, no HT, no TL, no 1 or 2, no definitions,
    only clues, no D, no G Y of course
perhaps on a per puzzle basis or for a competition(?)
or as a way to personally restrain yourself.
    like a NOH command to say No Hints  NOH 1-9 for different levels
        until you say OKH or some such.
        This is preserved in a cookie - like your preferred 'hive' display.
        so you can quit the browser and start again.
for a competition - announce a certain puzzle as the one for the day.
    this would work *only* with CP puzzles as all of the NYT puzzle
    answer words are available in various places - nytbee.com, shunn.net, etc
        add the page source!
    the competition puzzle has certain hint restrictions in place
        and these are announced.   as well as prizes :)
        and time limits - when is the last time?
    cheater programs?  yeah... :(  lexicon plus search, analysis
        participants would have to promise to not use them.
    command HR - what hint restrictions are in force for this puzzle?
    You enter the competition with a certain command
        then you give your name, the puzzle name.
    perhaps like 'ENTER CP5'
        you are prompted for mixed case Name, Location, and Contact Email
        and you are asked to promise to not use any other resource
    The time is noted along with your ip_id.
    When you achieve Queen Bee for the puzzle the timer is stopped
        and the time is noted.
    For competition, the hint restrictions are enforced regardless
        of what NOH/OKH the person has in place...
        It's on a per *puzzle* basis from person to person, browser to browser.
    Results are tallied.  and made available somehow
    prizes?
    A nice dream, anyway :).

another advantage - the clues from several people
    are shown all together (when using D) - and can be compared.
and another - the ok words are not visible in the page source!

?ECP to edit a puzzle that you created
    can add/remove words, update clues

when getting today's puzzle words (and pangrams)
update the lists used when creating puzzles
- the pangram lists and the list of words used in NYT puzzles
and the list of words from the big lexicon
easiest way is to simply regenerate and reindexize

    for testing of clues - make puzzles (with accompanying clues)
        with TION pangrams (adoption, antagonizing, annihilation)
        (also add clues for NYT puzzles that have
        those words as pangrams and either N or O as center letter
        - like conduction on 8/26/21)
        and give these various clues for NOON:
        - the opposite of midnight
        - a palindromic time of day
        - John Wayne movie - High ____
        and these clues for TOOT:
        - honk
        - a palindromic sound
        - snort of a drug

some way to preserve your accomplishments?
print it

expand advantages, making clues
what else?
the scramble thing - only when no message and no cmd

somewhere explain the keying off of ip address
    and browser signature

add to hint total when looking at all clues?
    clues are not as easy as dictionary definitions
    it's all just fun, anyway ...

document making clues for NYT puzzles

disadvantages
    - not easy to play on the phone
    - my software has not been thoroughly vetted and tested
          there are undoubtably other problems to be found
    - if many people start to use it
          the server may be overwhelmed, response time would be slow,
          and I'd need to optimize it and move it to its own server

more colors for cluers
    choose them better?

hint strategy
QBABM - ok, good for you
others don't mind 
myself ... if i get to Amazing by myself that's enough
one CAN game the system, of course
there are many answer sites shunn.net, nytbee.com, etc
    even the new york times site - page source
one can clear the puzzle and restart
e15p, e14p,... until you get all but one letter
    for only 2 hints
G Y, copy, C Y, paste - QB!
remember it is just a game!

at some point it becomes Art
practical use yields to beauty
to others its over-the-top impracticality
    seems insane and a waste of time
    but to the artist
    it gives meaning to life and is therapeutic

somehow cache the results of getting nyt hints?

TODO:


saved games - with timestamp? and purge ones more than a month old

_will_ work on the phone but it's awkward.
most everyone has a laptop or desktop
so we won't try to have the 7 letters clickable/tappable

in hidden fields we store the minimum state we need:
    date, puzzle data from archive, found words
and we compute the rest - score, max_score, rankings, hint table
it is plenty fast

the usual web trick is to store the puzzle state
in a stateless environment... with hidden fields
and using ip_id index into dbm and cookies
I want to avoid a registration step
    so we use ip and browser signature

=cut

use CGI;
my $q = CGI->new();
my $hive = $q->cookie('hive') || 0;
my %params = $q->Vars();
use CGI::Carp qw/
    fatalsToBrowser
/;

use BeeUtil qw/
    red
    trim
    ip_id
    slash_date
    shuffle
    ul
    table
    Tr
    th
    td
    bold
    div
    word_score
    JON
/;

use Date::Simple qw/
    today
    date
/;

use DB_File;

##############
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';
# the NYT archive
# key is d8
# value is seven center pangrams... | words
#-------------


###############
my %ip_date;
tie %ip_date, 'DB_File', 'ip_date.dbm';
# the current puzzles for each "person" = ip_address/browser_signature
# and their current state
#
# a complex hash key/value
# key is 'ip_address browser_signature puzzle_date'
#            0              1             2
# value is #hints all_pangrams_found ht_chosen tl_chosen rank words_found...
#            0         1                 2         3      4
#-------------

################
# clues for NYT puzzles are stored in the mysql database
# we want to avoid getting a connection each time just to
# see if there are any clues so ...
my %puzzle_has_clues;
tie %puzzle_has_clues, 'DB_File', 'nyt_puzzle_has_clues.dbm';

# key is puzzle_date
# value is does the puzzle have any clues? - always 1
# i.e. if the puzzle key is there then the puzzle has clues
# you can ask 'exists' if you'd like
#--------------

my $ip_id = ip_id();

sub my_puzzles {
    return
    map {
        [
            (split ' ', $_)[2],     # date/CPn
            (split ' ', $ip_date{$_})[1, 4] # all_pangrams, rank#
        ]
    }
    sort
    grep { index($_, $ip_id) == 0 }
    keys %ip_date;
}


my $comm_dir = 'community_puzzles';
my ($seven, $center, @pangrams);
my @seven;
my @ok_words;
my %clue_for;

# see sub load_nyt_clues
my %nyt_clues_for;        # key is word,
                          # value is [ { person_id => x, clue => y }, ... ]
my %nyt_cluer_name_of;    # key is person_id
my %nyt_cluer_color_for;  # key is person_id

my $log = 'http://logicalpoetry.com';

my $message = '';

sub my_today {
    my ($hour) = (localtime)[2];
    my $today = today();
    if ($hour < 3) {
        --$today;
    }
    return $today;
}

# Puzzle from which date are we dealing with?
# This is Very confusing, hacky, kludgy, and messy.
# Thorough testing is critical!
#
# NR random puzzle
# 2/23/19
# date from hidden field (date) - i.e. the "current" puzzle
# today
# CPx community puzzle
# Px puzzle from the current list
#
# Note: We preserve the current sort of the six/seven letters
# unless:
#    we switch puzzles
# or
#    hit Return in an empty field when there are no messages to clear
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
                $cmd = 'noop';
            }
            else {
                push @nums, $start .. $end;
            }
        }
        else {
            $message = "Illegal puzzle numbers: $nums";
            $cmd = 'noop';
        }
    }
    if ($cmd) {
        my @puzzles = my_puzzles();
        my $npuzzles = @puzzles;
        for my $n (@nums) {
            if ($n > $npuzzles) {
                $message = "$n: There are only $npuzzles current puzzles";
                $cmd = 'noop';
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
                    $cmd = 'noop';
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
elsif ($cmd eq 'x') {
    delete $ip_date{"$ip_id $params{date}"};
    my @puzzles = my_puzzles();
    if (@puzzles) {
        $date = $puzzles[0][0];
        $cmd = '';
    }
    else {
        $cmd = 't';
    }
}
if ($cmd eq 'xa') {
    my $today_d8 = $today->as_d8();
    for my $p (my_puzzles()) {
        if ($p->[0] ne $today_d8) {
            delete $ip_date{"$ip_id $p->[0]"};
        }
    }
    $date = $today_d8;
    $cmd = '';
}
elsif (my ($ncp) = $cmd =~ m{\A xcp \s* (\d+) \z}xms) {
    # did the current user create CP$ncp?
    my $fname = "community_puzzles/$ncp.txt";
    if (! -f $fname) {
        $message = "CP$ncp: No such Community Puzzle";
        $cmd = '';
    }
    else {
        my $href = do $fname;
        if ($href->{ip_id} ne $ip_id) {
            $message = ul(red("You did not create CP$ncp."));
            $cmd = '';
        }
        else {
            unlink $fname;
            # and just in case it is in the current list...
            delete $ip_date{"$ip_id CP$ncp"};
            $message = ul "Deleted CP$ncp";
            $cmd = 't';     # back to today
        }
    }
}
elsif (my ($puz_num) = $cmd =~ m{\A p \s* (\d+) \z}xms) {
    my @puzzles = my_puzzles();
    if ($puz_num > @puzzles) {
        $message = "Not that many puzzles";
        $cmd = 'noop';
    }
    my $puz_id = $puzzles[$puz_num-1][0];
    if ($puz_id =~ m{\A \d}xms) {
        $cmd = $puz_id;
    }
    else {
        # CP\d+
        # but we need lower case cp
        # since we have ... have what???
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
        $cmd = 'noop';
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
elsif ($cmd ne '1' && $cmd ne '2'
       && $cmd =~ m{\A ([\d/-]+) \z}xms
) {
    my $new_date = $1;
    my $dt = date($new_date);
    if ($dt) {
        # it is a valid date but is it in the range?
        if ($first <= $dt && $dt <= $today) {
            $date = $dt->as_d8();
            $params{found_words} = '';
            $new_puzzle = 1;
            $cmd = '';
        }
        else {
            $message = "Illegal date: $new_date";
            $cmd = 'noop';
        }
    }
    else {
        $message = "Illegal date: $new_date";
        $cmd = 'noop';
    }
}
if (! $date) {
    $date = $params{date};      # hidden field
}
if (! $date) {
    # today
    $date = $today->as_d8();
    $new_puzzle = 1;
}
my $show_date;
my $clues_are_present = '';
my $cp_href;

if ($cmd eq 'n' || $cmd eq 'p') {
    my @puzzles = my_puzzles();
    PUZ:
    for my $n (0 .. $#puzzles) {
        if ($puzzles[$n][0] eq $date) {
            my $x = $cmd eq 'n'? ($n == $#puzzles? 0: $n+1) 
                   :             ($n == 0        ? $#puzzles: $n-1);
            $date = $puzzles[$x][0];
            $cmd = '';
            last PUZ;
        }
    }
}

# we have a valid date. either d8 format or CP#
if ($date =~ m{\A\d}xms) {
    # d8 get the puzzle data from NYT Puzzles
    $show_date = date($date)->format("%B %e, %Y");
    if ($puzzle_has_clues{$date}) {
        $clues_are_present = " <span class=red2>*</span>";
    }
    my $puzzle = $puzzle{$date};

    my ($s, $t) = split /[|]/, $puzzle;
    ($seven, $center, @pangrams) = split ' ', $s;
    @seven = split //, $seven;
    @ok_words = split ' ', $t;
    # %clue_for is initialized from the database
    # but only if needed.  see sub load_nyt_clues
}
else {
    # Community Puzzles
    # $date is CP\d+
    $show_date = $date;
    my ($n) = $date =~ m{(\d+)}xms;
    my $fname = "$comm_dir/$n.txt";
    $cp_href = do $fname;
    $seven = $cp_href->{seven};
    @seven = split //, $seven;
    $center = $cp_href->{center};
    @pangrams = @{$cp_href->{pangrams}};
    @ok_words = @{$cp_href->{words}};
    %clue_for = %{$cp_href->{clues}};
}
my $nwords = @ok_words;
my $letter_regex = qr{([^$seven])}xms;  # see sub check_word
my $npangrams = @pangrams;

# get ready for hive == 3
my @seven_let;
if ($params{seven_let} && $date eq $params{date}) {
    @seven_let = split ' ', $params{seven_let};
}
else {
    @seven_let = map { uc } shuffle @seven;
}

my %is_pangram = map { $_ => 1 } @pangrams;
my %is_ok_word = map { $_ => 1 } @ok_words;
my @six;
if ($params{six} && $date eq $params{date}) {
    @six = split ' ', $params{six};
}
else {
    @six = map { uc }
           grep { $_ ne $center }
           shuffle
           @seven;
}

if ((! $cmd || $cmd eq 'noop') && ! $params{has_message}) {
    # We hit Return in an empy text field so
    # there is no command
    # and we didn't hit Return simply to clear a message
    # shuffle the @six and @seven_let
    @six = shuffle(@six);
    @seven_let = shuffle(@seven_let);
}
if ($cmd eq 'noop') {
    $cmd = '';
}

# this is done lazily 
# if we are going to do a define
# or an I (info)
#
# this is all very syntactically intense.
# also see 'i' and sub define
# is there a better data structure?
# perhaps have the colors in nytbee_get_clues or nytbee_get_cluers?
sub load_nyt_clues {
    if ($puzzle_has_clues{$date}) {
        # eliminate $href???
        %nyt_clues_for
            = %{ eval `curl -skL $log/cgi-bin/nytbee_get_clues/$date` };
        %nyt_cluer_name_of
            = %{ eval `curl -skL $log/cgi-bin/nytbee_get_cluers/$date` };
        my @cluer_colors = qw /
            tomato
            springgreen
            skyblue
            mediumorchid
            orange
            brown
        /;
        my $n = 0;
        for my $person_id (
            sort {
                # sort by name:
                $nyt_cluer_name_of{$a} cmp $nyt_cluer_name_of{$b}
            }
            # keys are person_id
            keys %nyt_cluer_name_of
        ) {
            $nyt_cluer_color_for{$person_id} = $cluer_colors[$n];
            ++$n;
        }
    }
}

my $max_score = 0;
for my $w (@ok_words) {
    $max_score += word_score($w, $is_pangram{$w});
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
my $ip_date_key = "$ip_id $date";
if (exists $ip_date{$ip_date_key}) {
    my ($ap, $rank);    # all pangrams is not needed here...
                        # rank is recomputed
    ($nhints, $ap, $ht_chosen, $tl_chosen, $rank, @found)
        = split ' ', $ip_date{$ip_date_key};
}
else {
    $nhints    = $new_puzzle? 0: $params{nhints} || 0;    # from before
    $ht_chosen = $new_puzzle? 0: $params{ht_chosen};
    $tl_chosen = $new_puzzle? 0: $params{tl_chosen};
    @found     = $new_puzzle? (): split ' ', $params{found_words};
}
my %is_found = map { $_ => 1 } @found;

my $score;
my $rank_name;
my $rank;

sub compute_score_and_rank {
    $score = 0;
    for my $w (@found) {
        $score += word_score($w, $is_pangram{$w});
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

# the online dictionaries often give many different
# definitions - let's just show 3 at the most.
# that's enough.  or maybe just 1?
# or all if Dcmd is d*.
# Dcmd is d or d*
#
# fullword is true only if we have given the entire word
# like 'd juice'
# and not dp, dx1, dx, or dxy
#
# if fullword we don't tally hints and we don't mask the word
sub define {
    my ($word, $Dcmd, $fullword) = @_;

    my $def = '';
    # a Community Puzzle clue
    if (! $fullword && exists $clue_for{$word}) {
        if (! $fullword) {
            $nhints += 3;
        }
        $def .= "<li style='list-style-type: circle'>$clue_for{$word}</li>\n";
        return $def if $Dcmd eq 'd'; 
    }
    # community contributed NYT Bee Puzzle clues
    elsif (! $fullword && exists $nyt_clues_for{$word}) {
        my $lw = length($word);
        for my $href (@{$nyt_clues_for{$word}}) {
            $def .= "<li style='list-style-type: circle'>"
                 .  "<span style='color:"
                 .  "$nyt_cluer_color_for{$href->{person_id}}'>"
                 .  "$href->{clue} - $lw"
                 .  "</span>"
                 .  "</li>\n"
                 ;
        }
        # just one word, perhaps several hints for that word
        $nhints += 3;
        return $def if $Dcmd eq 'd'; 
    }

    my ($html, @defs);

    # merriam-webster
    $html = `curl -skL https://www.merriam-webster.com/dictionary/$word`;
    # to catch an adequate definition for 'bought':
    push @defs, 'MERRIAM-WEBSTER:' if $Dcmd eq 'd*'; 
    push @defs, $html =~  m{meaning\s+of\s+$word\s+is\s+(.*?)[.]\s+How\s+to}xmsi;
    push @defs, $html =~ m{dtText(.*?)\n}xmsg;
    if ($Dcmd eq 'd*' || ! @defs || @defs < 3) {
        # some definitions (like 'from') use a different format
        # no clue why
        push @defs, $html =~ m{"unText">(.*?)</span>}xmsg;
    }
    for my $d (@defs) {
        $d = trim($d);
        $d =~ s{<[^>]*>}{}xmsg;   # strip tags
        $d =~ s{.*:\s+}{}xms;
    }
    if ($Dcmd eq 'd*' || ! @defs) {
        # oxford/lexico
        push @defs, 'OXFORD:' if $Dcmd eq 'd*';
        $html = `curl -skL https://www.lexico.com/en/definition/$word`;
        push @defs, $html =~ m{Lexical\s+data\s+-\s+en-us">(.*?)</span>}xmsg;
    }
    my $stars = '*' x length $word;
    # sometimes the definition is duplicated so ...
    my %seen;
    my @tidied_defs;

    DEF:
    for my $d (@defs) {
        $d =~ s{<[^>]*>}{}xmsg; # excise any tags
        $d =~ s{[^[:print:]]}{}xmsg; # excise any non-printing chars
        $d =~ s{$word}{$stars}xmsgi unless $fullword;    # hide the word
        $d =~ s{\A ">}{}xms;    # stray chars from somewhere
        if ($seen{$d}++) {
            next DEF;
        }
        push @tidied_defs, $d;
    }
    if ($Dcmd eq 'd') {
        @tidied_defs = splice @tidied_defs, 0, 3;
    }
    if (@tidied_defs && ! $fullword) {
        $nhints += 3;
    }
    $def .= join '',
            map {
                "<li>$_</li>\n";
            }
            @tidied_defs;
    return $def;
}

sub do_define {
    my ($Dcmd, $term) = @_;

    load_nyt_clues;
    my $line = "&mdash;" x 4;
    if ($term eq 'p') {
        for my $p (grep { !$is_found{$_} } @pangrams) {
            my $def = define($p, $Dcmd, 0);
            if ($def) {
                $message .= ul($def) . '--';
            }
        }
        $message =~ s{--\z}{}xms;
        $message =~ s{--}{$line<br>}xmsg;
        if ($message) {
            $message = "Pangrams:$message";
        }
        $cmd = '';
    }
    elsif ($term =~ m{\A ([a-z])(\d+) \z}xms) {
        my $let = $1;
        my $len = $2;
        if (index($seven, $let) < 0) {
            $message = ul(red(uc $cmd) . ": \U$let\E is not in \U$seven");
        }
        else {
            $message = '';
            for my $w (get_words($let, $len)) {
                my $def = define($w, $Dcmd, 0);
                if ($def) {
                    $message .= ul($def) .  '--';
                }
            }
            $message =~ s{--\z}{}xms;
            $message =~ s{--}{$line<br>}xmsg;
            if ($message) {
                $message = "\U$term\E:<br>$message";
            }
        }
        $cmd = '';
    }
    elsif ($term =~ m{\A ([a-z][a-z]) \z}xms) {
        my $lets = $1;
        if ($lets =~ $letter_regex) {
            $message = ul(red(uc $cmd) . ": \U$1\E is not in \U$seven");
        }
        else {
            $message = '';
            for my $w (get_words($lets)) {
                my $def = define($w, $Dcmd, 0);
                if ($def) {
                    $message .= ul($def) . '--';
                }
            }
            $message =~ s{--\z}{}xms;
            $message =~ s{--}{$line<br>}xmsg;
            if ($message) {
                $message = "\U$term\E:<br>$message";
            }
        }
        $cmd = '';
    }
    elsif ($term =~ m{\A ([a-z]) \z}xms) {
        my $let = $1;
        if ($let =~ $letter_regex) {
            $message = ul(red($cmd) . ": \U$1\E is not in \U$seven");
        }
        else {
            $message = '';
            for my $w (get_words($let)) {
                my $def = define($w, $Dcmd, 0);
                if ($def) {
                    $message .= ul($def) . '--';
                }
            }
            $message =~ s{--\z}{}xms;
            $message =~ s{--}{$line<br>}xmsg;
            if ($message) {
                $message = "\U$term\E:<br>$message";
            }
        }
        $cmd = '';
    }
}

sub reveal {
    my ($word, $nlets, $beg_end) = @_;

    my $dash = ' &ndash;';
    my $lw = length $word;
    if ($nlets >= $lw) {
        # silently ignore
        # can't see the whole word!
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
               ( $l? substr($_, 0, 1) eq $s
                   && length == $l
                :    m{\A $s}xms)
           }
           @ok_words;
}

sub do_reveal {
    my ($ev, $nlets, $term) = @_;
    my $err = 0;
    my $end = $ev eq 'e';
    if ($term eq 'p') {
        for my $p (grep { ! $is_found{$_} } @pangrams) {
            $message .= reveal($p, $nlets, $end);
        }
    }
    elsif (my ($first, $len) = $term =~ m{\A ([a-z])\s*(\d+)}xms) {
        if ($first =~ $letter_regex) {
            $message = ul(red($cmd) . ": \U$first\E is not in \U$seven");
            $err = 1;
        }
        else {
            if ($nlets == 1) {
                # silently gnore
            }
            else {
                for my $w (get_words($first, $len)) {
                    $message .= reveal($w, $nlets, $end);
                }
            }
        }
    }
    elsif (length($term) == 2) {
        # $term is two letters
        if ($term =~ $letter_regex) {
            $message = ul(red($cmd) . ": \U$1\E is not in \U$seven");
            $err = 1;
        }
        else {
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
    }
    else {
        # $term is one letter
        if ($term =~ $letter_regex) {
            $message = ul(red($cmd) . ": \U$1\E is not in \U$seven");
            $err = 1;
        }
        else {
            if ($nlets == 1) {
                # silently ignore
            }
            else {
                $term =~ s{\s}{}xmsg;       # if v2 a b instead of v2ab
                for my $w (get_words($term)) {
                    $message .= reveal($w, $nlets, $end);
                }
            }
        }
    }
    if (!$err && $message) {
        $message = "\U$cmd\E:<ul>$message</ul>";
    }
}

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
# do we have a reveal command?
elsif (my ($ev, $nlets, $term)
    = $cmd =~ m{
        \A ([ev])\s*(\d+)\s*(p|[a-z]|[a-z]\s*\d+|[a-z]\s*[a-z]) \z
      }xms
) {
    do_reveal($ev, $nlets, $term);
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
            $cols .= td(red('*') . $more);
        }
        $rows .= Tr($cols);
    }
    $message = ul(table({ cellpadding => 4}, $rows));
    $cmd = '';
}
elsif ($cmd =~ m{\A (d|d[*]) \s*  (p|[a-z]|[a-z]\d+|[a-z][a-z]) \z}xms) {
    my $Dcmd = $1;
    my $term = $2;
    do_define($Dcmd, $term);
    $cmd = '';
}
elsif ($cmd =~ m{\A (d[*]) \s* ([a-z]+) \z}xms
       ||
       $cmd =~ m{\A (d) \s+ ([a-z]+) \z}xms
) {
    # dictionary definitions of full words not clues
    my $Dcmd = $1;
    my $word = $2;
    $message = "\U$word:"
             . "<ul>"
             . define($word, $Dcmd, 1)
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
             sort
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
        my $sc = word_score($w, $is_pangram{$w});
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
elsif (my ($ncp) = $cmd =~ m{\A lcp \s*(\d*) \z}xms) {
    $ncp ||= 5;
    my $s = `cd community_puzzles; ls -tr1 [0-9]*.txt|tail -$ncp`;
    my @rows;
    my $title_row = Tr(th('&nbsp;'),
                       th({ style => 'text-align: left' }, 'Name'),
                       th({ style => 'text-align: left' }, 'Seven'),
                       th('Center'),
                       th('Words'),
                       th('Points'),
                       th('Pangrams'),
                    );

    for my $n (sort { $b <=> $a }
               $s =~ m{(\d+)}xmsg
    ) {
        my $href = do "community_puzzles/$n.txt";
        my @words = @{$href->{words}};
        my $nwords = @words;
        my @pangrams = @{$href->{pangrams}};
        my $npangrams = @pangrams;
        my %is_pangram = map { $_ => 1 } @pangrams;
        my $points = 0;
        for my $w (@words) {
            $points += word_score($w, $is_pangram{$w});
        }
        push @rows, Tr(td("CP$n"),
                       td($href->{name}),
                       td(uc $href->{seven}),
                       td({ style => 'text-align: center' },
                          uc $href->{center}),
                       td($nwords),
                       td($points),
                       td($npangrams),
                    );
    }
    if (@rows) {
        $message = table({ cellpadding => 3 }, $title_row, @rows);
    }
    $cmd = '';
}
elsif ($cmd eq 'ycp') {
    my $s = `cd community_puzzles; grep -l '$ip_id' *.txt`;
    my @nums = sort { $b <=> $a }
               $s =~ m{(\d+)}xmsg;
    my @rows;
    for my $n (@nums) {
        my $href = do "community_puzzles/$n.txt";
        my @pangrams = map { ucfirst } @{$href->{pangrams}};
        push @rows, Tr(td("<a target=nytbee onclick='set_focus();'"
                        . " href='$log/cgi-bin/edit_cp/$n'>CP$n</a>"),
                       td(slash_date($href->{created})),
                       td(@pangrams),
                    );
    }
    $message = "Your Community Puzzles:<p>"
             . table({ cellpadding => 5 }, @rows);
    $cmd = '';
}
elsif ($cmd eq 'l') {
    my @puzzles = my_puzzles();
    my $n = 1;
    for my $p (@puzzles) {
        my $cur = $p->[0] eq $date? red('*'): '';
        my $pg  = $p->[1]? '&nbsp;&nbsp;p': '';
        $message .= Tr(
                        td($n) . td($cur)
                      . td({ style => 'text-align: left' }, slash_date($p->[0]))
                      . td({ style => 'text-align: left'},
                           $ranks[$p->[2]]->{name})
                      . td($pg)
                    );
        ++$n;
    }
    $message = table({ cellpadding => 4}, $message);
    $cmd = '';
}
elsif ($cmd eq 'cl') {
    my $s = $ip_id;
    $s =~ s{\s}{_}xmsg;
    $message = `curl -skL $log/cgi-bin/nytbee_clue_dates/$s`;
    $cmd = '';
}
elsif ($cmd eq 'f') {
    # look for same 7
    my @puz;
    while (my ($dt, $puz) = each %puzzle) {
        if (substr($puz, 0, 7) eq $seven) {
            push @puz, [ $dt, uc substr($puz, 8, 1)
                              . ($dt eq $date? ' *': '') ];
        }
    }
    my $rows = '';
    for my $p (sort { $a->[0] cmp $b->[0] } @puz) {
        $rows .= Tr(td(slash_date($p->[0])),
                    td({ style => 'text-align: left' }, $p->[1]));
    }
    # also search the community puzzles
    my $s = `cd community_puzzles; grep -l 'seven.*=>.*$seven' *.txt`;
    for my $n ($s =~ m{(\d+)}xmsg) {
        my $href = do "community_puzzles/$n.txt";
        $rows .= Tr(td("CP$n"), td({ style => 'text-align: left' }, uc $href->{center}));
    }
    $message = table({ cellpadding => 5}, $rows);
    $cmd = '';
}
elsif ($cmd =~ m{\A s \s+ ([a-z]+) \s* \z}xms) {
    # search the archive for the word
    # we're searching everything after the |
    my $word = $1;
    my @dates;
    while (my ($dt, $puz) = each %puzzle) {
        $puz =~ s{\A [^|]* [|]}{}xms;
        if ($puz =~ m{\b$word\b}xms) {
            push @dates, $dt;
        }
    }
    $message = join '',
               map {
                   slash_date($_) . '<br>'
               }
               sort
               @dates
               ;
    # also search the community puzzles
    my $s = qx!cd community_puzzles; grep -l "words.*=>.*'$word'" [0-9]*.txt!;
    $message .= join '<br>',
                map { "CP$_" }
                sort { $a <=> $b }
                $s =~ m{(\d+)}xmsg;
    if ($message) {
        $message = "\U$word\E:<br>$message";
    }
    $cmd = '';
}
elsif ($cmd eq 'h') {
    $hive = ($hive+1) % 4;
    $cmd = '';
}
elsif ($cmd =~ m{\A h \s* ([1-4]) \z}xms) {
    $hive = $1-1;
    $cmd = '';
}

# now to prepare the display the words we have found
# some subset, some order
my $order = 0;
my $prefix = '';
my $pattern = '';
my $limit = 0;
my @words_found;
my $word_col = 0;
if ($cmd eq 'w') {
    @words_found = @found;
    $cmd = '';
}
elsif ($cmd eq '1w') {
    $word_col = 1;
    @words_found = sort @found;
    $cmd = '';
}
elsif (($pattern) = $cmd =~ m{\A w \s* / \s* (.*) \z}xms) {
    @words_found = grep { /$pattern/xms } sort @found;
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
        return "does not contain: " . red(uc($center));
    }
    if (my ($c) = $w =~ $letter_regex) {
        return "\U$c\E is not in \U$seven";
    }
    if (! exists $is_ok_word{$w}) {
        return "not in word list";
    }
    return '';
}
WORD:
for my $w (@new_words) {
    next WORD if $w eq '1w';        # hack!
    if (my $mess = check_word($w)) {
        $not_okay_words .= "<span class=not_okay>"
                        .  uc($w)
                        .  "</span>: $mess<br>";
    }
    else {
        $is_new_word{$w} = 1;
        if (! $is_found{$w}) {
            push @found, $w;
            $is_found{$w} = 1;
        }
        else {
            $not_okay_words .= "<span class=not_okay>"
                            .  uc($w)
                            .  "</span>: already found<br>";
        }
    }
}

# now that we have added the new words...
compute_score_and_rank();

if (! $prefix && ! $pattern && ! $limit && ! @words_found) {
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
if ($word_col == 1) {
    my @rows = map {
                   Tr(td({ style => 'text-align: left' }, ucfirst))
               }
               @words_found;
    $found_words = ul(table(@rows));
}
else {
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
}

# get the HT and TL tables ready
# $sums{$c}{1} is the rightmost column (sigma)
#
my %sums;
my %two_lets;
my $max_len = 0;
my %first_char;
WORD:
for my $w (@ok_words) {
    my $l = length($w);
    if ($max_len < $l) {
        $max_len = $l;
    }
    my $c1 = substr($w, 0, 1);
    ++$first_char{$c1};
    if ($is_found{$w}) {
        # skip it
        next WORD;
    }
    my $c2 = substr($w, 0, 2);
    ++$sums{$c1}{$l};
    ++$sums{$c1}{1};
    ++$two_lets{$c2};
}
my $bingo = keys %first_char == 7? ', Bingo': '';

# now that #we have computed %sums and %two_lets
# perhaps $cmd was not words to add after all...
if ($cmd eq '1') {
    # find a random non-zero entry in the hint table
    my @entries;
    for my $l (4 .. $max_len) {
        for my $c (@seven) {
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
my $show_clue_form = '';
if ($cmd eq 'i') {
    $message = "Words: $nwords, Points: $max_score, "
             . "Pangrams: $npangrams$perfect$bingo";
    if ($date =~ m{\A CP}xms) {
        my ($n) = $date =~ m{(\d+)}xms;
        my $created = date($cp_href->{created})->format("%B %e, %Y");
        my $s = <<"EOH";
<span class=pointer style='color: blue' onclick='clues_by(0)'>$cp_href->{name}</span>, $cp_href->{location}<br>
EOH
        $message .= "<br>Community Puzzle #$n - $created<br>Created by $s";
        $show_clue_form = <<"EOH";
<form target=nytbee
      id=clues_by
      action=/cgi-bin/nytbee_clues_by
      method=POST
>
<input type=hidden id=person_id name=person_id>
<input type=hidden id=date name=date value=$date>
<input type=hidden id=found name=found value='@found'>
<input type=hidden name=format value=1>
</form>
EOH
    }
    else {
        load_nyt_clues;
        if (%nyt_cluer_name_of) {
            my @names;
            for my $person_id (
                sort {
                    $nyt_cluer_name_of{$a} cmp $nyt_cluer_name_of{$b}
                }
                keys %nyt_cluer_name_of
            ) {
                push @names,
                  "<span"
                  . " class=pointer"
                  . " style='color: $nyt_cluer_color_for{$person_id}'"
                  . " onclick='clues_by($person_id);'>"
                  . $nyt_cluer_name_of{$person_id}
                  . "</span>"
                  ;
            }
            $message .= "<br>Clues by " . join ', ', @names;
        }
        $show_clue_form = <<"EOH";
<form target=nytbee
      id=clues_by
      action=/cgi-bin/nytbee_clues_by
      method=POST
>
<input type=hidden id=person_id name=person_id>
<input type=hidden id=date name=date value=$date>
<input type=hidden id=found name=found value='@found'>
<input type=hidden name=format value=1>
</form>
EOH
    }
    $cmd = '';
}

# the hint tables
my $hint_table = '';
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
        for my $l (4 .. $max_len) {
            $hint_table .= "<td>"
                        .  ($sums{$c}{$l}?
                               "<span class=pointer"
                             . qq! onclick="define_ht('$c', $l);">!
                             . "$sums{$c}{$l}</span>"
                          : '&nbsp;-&nbsp;')
                        . "</td>";
        }
        $hint_table .= th($sums{$c}{1} || 0) . "</tr>\n";  # sigma
        $tot += $sums{$c}{1};
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
$ip_date{$ip_date_key}
    = "$nhints $all_pangrams $ht_chosen $tl_chosen $rank @found";

my $has_message = 0;
if ($message) {
    $message .= '<p>';
    $has_message = 1;
}
my $create_add
    = "<a  onclick='set_focus();' target=_blank href='$log/nytbee/mkpuz.html'>"
    . "Create Puzzle</a>";
my $add_clues_form = '';
if ($date =~ m{\A \d}xms) {
    $create_add
        .= "<br><span class=add_clues onclick='add_clues();'>Add Clues</span>";
    $add_clues_form = <<"EOH";
<form target=_blank
      id=add_clues
      action=$log/cgi-bin/nytbee_mkclues
      method=POST
>
<input type=hidden id=date name=date value=$date>
<input type=hidden id=found name=found value='@found'>
</form>
EOH
}

# now to display everything
# cgi-bin/style.css?

my $cookie = $q->cookie(
    -name    => 'hive',
    -value   => $hive,
    -expires => '+20y'
);
print $q->header(-cookie => $cookie);
my $letters = '';
my @coords;
my $let_size;
my $img_left_margin;
if ($hive == 0) {
    $letters = <<"EOH";
<pre>
     $six[0]   $six[1]
   $six[2]   <span class=red2>\U$center\E</span>   $six[3]
     $six[4]   $six[5]
</pre>
EOH
}
elsif ($hive == 1) {        # bee hive honeycomb
    $letters = "<p><img class=img src=/nytbee/pics/hive.jpg height=240><p>";
    $letters .= "<span class='p0 ab'>\U$center\E</span>";
    for my $i (1 .. 6) {
        $letters .= "<span class='p$i ab'>$six[$i-1]</span>";
    }
    $let_size = 24;
    $img_left_margin = 37;
    #       1
    #    2     3
    #       0
    #    4     5
    #       6
    @coords = (
        { top => 214, left => 173, }, #0    208 168
        { top => 134, left => 173, }, #1
        { top => 175, left => 104, }, #2
        { top => 175, left => 241, }, #3
        { top => 253, left => 104, }, #4
        { top => 253, left => 239, }, #5
        { top => 295, left => 173, }, #6
    );
    # adjust an I
    for my $i (1 .. 6) {
        if ($six[$i-1] eq 'I') {
            $coords[$i]{left} += 6;
        }
    }
    if ($center eq 'i') {
        $coords[0]{left} += 9;
    }
}
elsif ($hive == 2) {        # flower
    $letters = "<p><img class=img src=/nytbee/pics/flower.jpg height=250><p>";
    $letters .= "<span class='p0 ab white'>\U$center\E</span>";
    for my $i (1 .. 6) {
        $letters .= "<span class='p$i ab'>$six[$i-1]</span>";
    }
    $let_size = 24;
    $img_left_margin = 30;
    #
    #   2   3
    # 4   0   5
    #   6   1
    #
    @coords = (
        { top => 220, left => 179, }, #0
        { top => 277, left => 213, }, #1
        { top => 160, left => 143, }, #2
        { top => 160, left => 213, }, #3
        { top => 220, left => 105, }, #4
        { top => 220, left => 243, }, #5
        { top => 277, left => 138, }, #6
    );
    # adjust an I
    for my $i (1 .. 6) {
        if ($six[$i-1] eq 'I') {
            $coords[$i]{left} += 7;
        }
    }
    if ($center eq 'i') {
        $coords[0]{left} += 7;
    }
}
elsif ($hive == 3) {
    $letters = "<pre>\n  ";
    for my $c (@seven_let) {
        if ($c eq uc $center) {
            $letters .= "<span class=red2>$c</span> ";
        }
        else {
            $letters .="$c ";
        }
    }
    $letters .= "</pre>";
}
my $letter_styles = '';
if (@coords) {
    for my $i (0 .. 6) {
        $letter_styles .= <<"EOS";
.p$i {
    top: $coords[$i]{top}px;
    left: $coords[$i]{left}px;
}
EOS
    }
}
print <<"EOH";
<html>
<head>
<style>
.img {
    margin-left: ${img_left_margin}px;
}
.ab {
    position: absolute;
    font-weight: bold;
    font-family: Arial;
    font-size: ${let_size}px;
}
$letter_styles
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
.create_add, .help {
    font-size: 13pt;
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
    margin: .3in;
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
.white {
    color: white;
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
.add_clues {
    cursor: pointer;
    color: blue;
}
</style>
<script>
function add_clues() {
    set_focus();
    document.getElementById('add_clues').submit();
}
function define_tl(two_let) {
    document.getElementById('new_words').value = 'D' + two_let;
    document.getElementById('main').submit();
}
function define_ht(c, n) {
    document.getElementById('new_words').value = 'D' + c + n;
    document.getElementById('main').submit();
}
function define_ol(c) {
    document.getElementById('new_words').value = 'D' + c;
    document.getElementById('main').submit();
}
function clues_by(person_id) {
    document.getElementById('person_id').value = person_id;
    document.getElementById('clues_by').submit();
    set_focus();
}
function set_focus() {
    document.form.new_words.focus();
    return true;
}
</script>
</head>
<body>
<div class=float-child1>
    <a target=_blank href='https://www.nytimes.com/subscription'>NY Times</a> Spelling Bee<br>$show_date$clues_are_present
</div>
<div class=float-child2>
     <img width=50 src=/pics/bee-logo.jpg>
</div>
<div class=float-child3>
    <span class=help><a target=_blank onclick="set_focus();" href='$log/nytbee/help.html#words'>Help</a></span><br><span class=create_add>$create_add</span>
</div>
<br><br>
<form id=main name=form method=POST>
<input type=hidden name=date value='$date'>
<input type=hidden name=found_words value='@found'>
<input type=hidden name=nhints value=$nhints>
<input type=hidden name=ht_chosen value=$ht_chosen>
<input type=hidden name=tl_chosen value=$tl_chosen>
<input type=hidden name=has_message value=$has_message>
<input type=hidden name=six value='@six'>
<input type=hidden name=seven_let value='@seven_let'>
$letters
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
$show_clue_form$add_clues_form
</body>
<script>set_focus();</script>
</html>
EOH
