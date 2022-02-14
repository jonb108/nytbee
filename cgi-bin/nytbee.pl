#!/usr/bin/perl
use strict;
use warnings;

=comment

?? Safari:
try {
    // try to use Clipboard API
    await navigator.clipboard.writeText(text);
    return true
} catch (_) {
    // Clipboard API is not supported
    const el = document.createElement('textarea')
    el.value = text
    document.body.appendChild(el)
    el.select()
    const result = document.execCommand('copy')
    document.body.removeChild(el)
    return result === 'unsuccessful' ? false : true
}

to email: https://cs.brynmawr.edu/~dkumar/

ask John Napiorkowski about FAST CGI or Dancer
    or Plack or PSGI or ... mod_perl
    if needed...

it is so fast - FastCGI or mod_perl or ...
    it's tricky with limited ability to install this or that
    dancer?

test suite!

tips, tricks
    Tab to get focus on new_words
    pangram game or getting to a certain rank

film(s)

Art is about "drawing the line".
    we're getting very close to the end.
    so perhaps put your new ideas in a
    section called "Future Plans?"
    when are we done?  when adding anything else
    spoils what is already there.
    or when explaining the new thing is simply
    too complicated and would put off people
    from trying it in the first place!

find beta testers - friends and the hivemind
should it be labeled NYT Bee, ToBee, or what?

<script>
several functions that
may not be used - make them conditional
</script>

make more additions to js/

divide styles into two - static and dynamic
    static can be cached the browser
    cgi_style.css is a start
scripts, too

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
    The time is noted along with your uuid.
    When you achieve Queen Bee for the puzzle the timer is stopped
        and the time is noted.
    For competition, the hint restrictions are enforced regardless
        of what NOH/OKH the person has in place...
        It's on a per *puzzle* basis from person to person, browser to browser.
    Results are tallied.  and made available somehow
    prizes?
    A nice dream, anyway :).

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

add to hint total when looking at all clues?
    clues are not as easy as dictionary definitions
    it's all just fun, anyway ...

at some point it becomes Art
practical use yields to beauty
to others its over-the-top impracticality
    seems insane and a waste of time
    but to the artist
    it gives meaning to life and is therapeutic

=cut

use CGI;
use CGI::Carp qw/
    fatalsToBrowser
/;
use BeeUtil qw/
    uniq_chars
    cgi_header
    my_today
    red
    trim
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
    $log
    $cgi
    $cgi_dir
    get_html
/;
use Date::Simple qw/
    today
    date
/;
use DB_File;
use DB_File::Lock;
use Data::Dumper qw/
    Dumper
/;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

my $q = CGI->new();
my $hive = $q->param('hive') || $q->cookie('hive') || 1;
my $hive_cookie = $q->cookie(
    -name    => 'hive',
    -value    => $hive,
    -expires => '+20y',
);
my $uuid = cgi_header($q, $hive_cookie);
my %params = $q->Vars();
if ($params{new_words} =~ m{\A \s* id \s+}xmsi) {
    # we took care of this case in cgi_header
    $params{new_words} = '';
}
# search for 'id' below


##############
my %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';
# the NYT archive
# key is d8
# value is seven center pangrams... | words
#-------------

################
# a better way of storing the current puzzle list for *everyone*
my %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File::Lock', 'cur_puzzles_store.dbm',
                        O_CREAT|O_RDWR, 0666, $DB_HASH, 'write';

# key is the uuid ("session" id)
# value is a Data::Dumper created *string* representing a hash
#     whose keys are the $date (or cp#)
#     and the value is:
#     #hints all_pangrams_found ht_chosen tl_chosen rank words_found...
#     as above
#---------------
my %cur_puzzles;        # the current puzzles for the _current_ user
my $s = $cur_puzzles_store{$uuid};
if ($s) {
    %cur_puzzles = %{ eval $s };    # the key point #1 (see below for #2)
}
# otherwise this is a brand new user...

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

#
# returns an array of arrayrefs representing
# the current list of puzzles.  each array ref has two elements:
#   0 date (yyyymmdd or CP#)
#   1 all_pangrams?(0/1) rank#
#
sub my_puzzles {
    return
    map {
        [
            $_,
            (split ' ', $cur_puzzles{$_})[1, 4]
        ]
    }
    sort
    keys %cur_puzzles;
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

my $message = '';

# Puzzle from which date are we dealing with?
# This is Very confusing, hacky, kludgy, and messy.
# Thorough testing is critical!
#
# content of $params{new_words}:
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

my $show_Heading    = exists $params{show_Heading}?
                             $params{show_Heading}: 1;
my $show_WordList   = exists $params{show_WordList}?
                             $params{show_WordList}: 1;
my $show_RankImage  = exists $params{show_RankImage}?
                             $params{show_RankImage}: 1;
my $show_ZeroRowCol = exists $params{show_ZeroRowCol}?
                             $params{show_ZeroRowCol}: 1;

#
# SO ... what puzzle is current?
# we need to set the variable $date.
# the value of $cmd might very well change what puzzle is current.
#
#       T, NR,
#       X, XA, Xnums,
#       N, P, P#
#       CP#, XCP,
#       mm/dd/yy, mm/dd, dd
#
# the most common case is that the $date CGI parameter
# (from a hidden field) is the current date we are dealing with.
# next most common is that we have no date at all and
# will load the most recent NYT puzzle - today's.
#
# then there is the path_info - appended to nytbee.pl/ 
# 
my $first = date('5/29/18');
my $date;
my $today = my_today();
my $new_puzzle = 0;

# initial guess at what puzzle we are looking at
$date = substr($q->path_info(), 1);       # no need for the leading /
                                          # it is either yyyymmdd or CPx
if (!$date || $date !~ m{\A \d{8} | CP\d+ \z}xms) {
    $date = $params{date};      # hidden field
}
if (! $date) {
    # today
    $date = $today->as_d8();
    $new_puzzle = 1;
}

# Remove a set of current puzzles.
if (my ($nums) = $cmd =~ m{\A x \s* ([\d,\s-]+) \z}xms) {
    #
    # setting $cmd = '' means we are all done
    # with this command and need to move on.
    #
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
    my @puzzles = my_puzzles();
    if (@nums) {
        my $npuzzles = @puzzles;
        for my $n (@nums) {
            if ($n > $npuzzles) {
                $message = "$n: There are only $npuzzles current puzzles";
                $cmd = '';
            }
        }
    }
    if ($cmd) {
        # @nums are valid puzzle numbers (base 1)
        for my $n (@nums) {
            delete $cur_puzzles{ $puzzles[$n-1][0] };
        }
        # and reget the puzzles
        @puzzles = my_puzzles();
        if (! @puzzles) {
            $date = $today->as_d8();
            $cmd = '';
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
                $date = $puzzles[-1][0];
            }
        }
        $cmd = '';
    }
}
elsif ($cmd eq 'x') {
    delete $cur_puzzles{$date};
    my @puzzles = my_puzzles();
    $date = @puzzles? $puzzles[0][0]: $today->as_d8();
    $cmd = '';
}
elsif ($cmd eq 'xa') {
    my $today_d8 = $today->as_d8();
    my @puzzles = my_puzzles();
    for my $p (@puzzles) {
        my $dt = $p->[0];
        if ($dt ne $today_d8) {
            delete $cur_puzzles{$dt};
        }
    }
    if ($date ne $today_d8) {
        $new_puzzle = 1;
    }
    $date = $today_d8;
    $cmd = '';
}
elsif (my ($ncp) = $cmd =~ m{\A xcp \s* (\d+) \z}xms) {
    # did the current user create CP$ncp?
    my $fname = "community_puzzles/$ncp.txt";
    if (! -f $fname) {
        $message = "CP$ncp: No such Community Puzzle";
    }
    else {
        my $href = do $fname;
        if ($href->{uuid} ne $uuid) {
            $message = ul(red("You did not create CP$ncp."));
        }
        else {
            unlink $fname;
            # and just in case it is in the current list...
            delete $cur_puzzles{"CP$ncp"};
            $message = ul "Deleted CP$ncp";
            $date = $today->as_d8();
            # and delete all clues
            system "$cgi_dir/cp_del_clues.pl $ncp";
        }
    }
    $cmd = '';
}
elsif (my ($puz_num) = $cmd =~ m{\A p \s* ([1-9]\d*) \z}xms) {
    my @puzzles = my_puzzles();
    if ($puz_num > @puzzles) {
        $message = "Not that many puzzles";
    }
    else {
        my $puz_id = $puzzles[$puz_num-1][0];
        if ($puz_id =~ m{\A \d}xms) {
            $date = $puz_id;
        }
        else {
            # CP\d+
            # but we need lower case cp
            # since we have ... have what???
            $date = lc $puz_id;
        }
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A n \s* r \z}xms) {
    # random date since $first
    my $ndays = $today - $first + 1;
    $date = $first + int(rand $ndays);
    $date = $date->as_d8();
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
    $new_puzzle = 1;
    $cmd = '';
}
elsif ($cmd eq 'n' || $cmd eq 'p') {
    my @puzzles = my_puzzles();
    PUZ:
    for my $n (0 .. $#puzzles) {
        if ($puzzles[$n][0] eq $date) {
            my $x = $cmd eq 'n'? ($n == $#puzzles?         0: $n+1) 
                   :             ($n == 0        ? $#puzzles: $n-1);
            $date = $puzzles[$x][0];
            $cmd = '';
            last PUZ;
        }
    }
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

my $show_date;
my $clues_are_present = '';
my $cp_href;

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

# get ready for hive == 3 (seven straight letters)
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
    # We hit Return in an empty text field so
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
# perhaps have the colors in nytbee_get_clues.pl or nytbee_get_cluers.pl?
sub load_nyt_clues {
    if ($puzzle_has_clues{$date}) {
        %nyt_clues_for
            = %{ eval get_html "$log/cgi-bin/nytbee_get_clues.pl/$date" };
        %nyt_cluer_name_of
            = %{ eval get_html "$log/cgi-bin/nytbee_get_cluers.pl/$date" };
        my @cluer_colors = qw /
            green
            tomato
            skyblue
            orange
            brown
            coral
            greenyellow
            indigo
            lightseagreen
            maroon
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

my (@found, $nhints, $ht_chosen, $tl_chosen,
    $score_at_first_hint, $score, $rank_name, $rank);

sub add_hints {
    my ($n) = @_;
    if ($score_at_first_hint < 0) {
        $score_at_first_hint = $score;
    }
    $nhints += $n;
}

if (exists $cur_puzzles{$date}) {
    my ($ap, $rank);    # all pangrams is not needed here...
                        # rank is recomputed
    ($nhints, $ap, $ht_chosen,
     $tl_chosen, $rank, $score_at_first_hint,
     @found)
        = split ' ', $cur_puzzles{$date};
}
else {
    $nhints    = 0;
    $ht_chosen = 0;
    $tl_chosen = 0;
    $score_at_first_hint = -1;  # -1 since we may ask for a hint
                                # at the very beginning!
    @found     = ();
}
my %is_found = map { $_ => 1 } @found;

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
            add_hints(3);
        }
        $def .= "<li style='list-style-type: circle'>$clue_for{$word}</li>\n";
        return $def if $Dcmd eq 'd'; 
    }
    # community contributed NYT Bee Puzzle clues
    elsif (! $fullword && exists $nyt_clues_for{$word}) {
        for my $href (@{$nyt_clues_for{$word}}) {
            $def .= "<li style='list-style-type: circle'>"
                 .  "<span style='color:"
                 .  "$nyt_cluer_color_for{$href->{person_id}}'>"
                 .  $href->{clue}
                 .  "</span>"
                 .  "</li>\n"
                 ;
        }
        # just one word, perhaps several hints for that word
        add_hints(3);
        return $def if $Dcmd eq 'd'; 
    }

    my ($html, @defs);

    my $max = 20;   # without this D*TIME causes a fatal error! :(

    # merriam-webster
    $html = get_html "https://www.merriam-webster.com/dictionary/$word";
    # to catch an adequate definition for 'bought':
    push @defs, 'MERRIAM-WEBSTER:' if $Dcmd eq 'd*'; 
    push @defs, $html =~  m{meaning\s+of\s+$word\s+is\s+(.*?)[.]\s+How\s+to}xmsi;
    push @defs, $html =~ m{dtText(.*?)\n}xmsg;
    $#defs = $max if @defs > $max;
    if ($Dcmd eq 'd*' || ! @defs || @defs < 3) {
        # some definitions (like 'from') use a different format
        # no clue why
        push @defs, $html =~ m{"unText">(.*?)</span>}xmsg;
        $#defs = $max if @defs > $max;
    }
    for my $d (@defs) {
        $d = trim($d);
        $d =~ s{<[^>]*>}{}xmsg;   # strip tags
        $d =~ s{.*:\s+}{}xms;
    }
    if ($Dcmd eq 'd*' || ! @defs) {
        # oxford/lexico
        push @defs, 'OXFORD:' if $Dcmd eq 'd*';
        $html = get_html "https://www.lexico.com/en/definition/$word";
        push @defs, $html =~ m{Lexical\s+data\s+-\s+en-us">(.*?)</span>}xmsg;
        $#defs = $max if @defs > $max;
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
        $d =~ s{[^[:print:]]}{}xmsga;
        if ($seen{$d}++) {
            next DEF;
        }
        push @tidied_defs, $d;
    }
    if ($Dcmd eq 'd') {
        @tidied_defs = splice @tidied_defs, 0, 3;
    }
    if (@tidied_defs && ! $fullword) {
        add_hints(3);
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
    elsif ($term eq 'r') {
        # a random word that has not yet been found
        my @words = grep { !$is_found{$_} }
                    @ok_words;
        $message = define($words[ rand @words ], $Dcmd);
        add_hints(-2);  # hack 
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
    add_hints(2);
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
        add_hints(10);
    }
    $cmd = '';
}
elsif ($cmd eq 'tl') {
    if (! $tl_chosen) {
        $tl_chosen = 1;
        add_hints(5);
    }
    $cmd = '';
}
elsif ($cmd eq 'he') {
    $show_Heading = ! $show_Heading;
    $cmd = '';
}
elsif ($cmd eq 'wl') {
    $show_WordList = ! $show_WordList;
    $cmd = '';
}
elsif ($cmd eq 'im') {
    $show_RankImage = ! $show_RankImage;
    $cmd = '';
}
elsif ($cmd eq 'co') {
    $show_ZeroRowCol = ! $show_ZeroRowCol;
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
elsif ($cmd =~ m{\A (d|d[*]) \s*  (p|r|[a-z]\d+|[a-z][a-z]) \z}xms) {
    my $Dcmd = $1;
    my $term = $2;
    do_define($Dcmd, $term);
    $cmd = '';
}
elsif ($cmd =~ m{\A (d[*]) \s* ([a-z ]+) \z}xms
       ||
       $cmd =~ m{\A (d) \s+ ([a-z ]+) \z}xms
) {
    # dictionary definitions of full words not clues
    my $Dcmd = $1;
    my $words = $2;
    my @words = split ' ', $words;
    for my $word (@words) {
        $message .= "\U$word:"
                 .  "<ul>"
                 .  define($word, $Dcmd, 1)
                 .  "</ul><p>"
                 ;
    }
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
        add_hints(@words * 5);
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
    $score_at_first_hint = -1;
    $cmd = '';
}
elsif ($cmd eq 'sc') {
    my $r = 6;
    my @rows;
    my $tot = 0;
    if ($tot == $score_at_first_hint) {
        # they asked for a hint right away!
        push @rows, Tr(td({ colspan => 3 }, '<hr>'));
    }
    my $space = '&nbsp;' x 2;
    for my $w (@found) {
        my $sc = word_score($w, $is_pangram{$w});
        my $rank_name = '';
        $tot += $sc;
        if ($tot >= $ranks[$r]{value}) {
            $rank_name = $ranks[$r]{name};
            ++$r;
        }
        my $s = ucfirst $w;
        if ($is_pangram{$w}) {
            $s = color_pg($s);
        }
        push @rows, Tr(td($s),
                       td($space.$sc),
                       td($space.$tot),
                       td({ class => 'lt' }, $space.$rank_name),
                      );
        if ($tot == $score_at_first_hint) {
            # yes == above
            push @rows, Tr(td({ colspan => 3 }, '<hr>'));
        }
    }
    $message = table({ cellpadding => 2 }, @rows);
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
                       th(''),
                       th({ class => 'lt' }, 'Name'),
                       th({ class => 'lt' }, 'Seven'),
                       th('Center'),
                       th('Words'),
                       th('Points'),
                       th('Pangrams'),
                    );
    my %is_in_list = map { $_->[0] => 1 } my_puzzles();
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
        my $cpn = "CP$n";
        push @rows, Tr(td({ class => 'rt' },
                          qq!<span class=link onclick="new_date('$cpn');">!
                          . "$cpn</span>"),
                       td(     $date eq $cpn? red('*')
                          :$is_in_list{$cpn}? '*'
                          :                   ''),
                       td({ class => 'lt' }, $href->{name}),
                       td({ class => 'lt' }, uc $href->{seven}),
                       td({ class => 'cn' }, uc $href->{center}),
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
    my $s = `cd community_puzzles; grep -l '$uuid' *.txt`;
    my @nums = sort { $b <=> $a }
               $s =~ m{(\d+)}xmsg;
    my @rows;
    for my $n (@nums) {
        my $href = do "community_puzzles/$n.txt";
        my @pangrams = map { ucfirst } @{$href->{pangrams}};
        push @rows, Tr(td("<a target=nytbee onclick='set_focus();'"
                        . " href='$log/cgi-bin/edit_cp.pl/$n'>CP$n</a>"),
                       td(slash_date($href->{created})),
                       td({ class => 'lt' }, @pangrams),
                    );
    }
    $message = "Your Community Puzzles:<p>"
             . table({ cellpadding => 5 }, @rows);
    $cmd = '';
}
elsif ($cmd eq 'l') {
    my $n = 1;
    for my $p (my_puzzles()) {
        my $cur = $p->[0] eq $date? red('*'): '';
        my $pg  = $p->[1]? '&nbsp;&nbsp;p': '';
        $message .= Tr(
                       td($n),
                       td($cur),
                       td({ class => 'lt' }, 
                      qq!<span class=link onclick="new_date('$p->[0]');">!
                          . slash_date($p->[0])
                          . "<span>"),
                      td({ class => 'lt' }, $ranks[$p->[2]]->{name}),
                      td($pg)
                    );
        ++$n;
    }
    $message = table({ cellpadding => 4}, $message);
    $cmd = '';
}
elsif ($cmd eq 'cl') {
    my %is_in_list = map { $_->[0] => 1 } my_puzzles();
    my @dates = `$cgi_dir/nytbee_clue_dates.pl $uuid`;
    chomp @dates;
    if (!@dates) {
        $message = '';
    }
    else {
        $message
            = 'Puzzles you clued:<br>'
            . table(
                  map {
                      Tr(td(qq!<span class=link onclick="new_date('$_');">!
                           .slash_date($_)
                           .'</span>'),
                         td($is_in_list{$_}? ($_ eq $date? red('*'): '*'): ''),
                        )
                  }
                  @dates
              );
    }
    $cmd = '';
}
elsif ($cmd eq 'f') {
    # look for same 7
    my %is_in_list = map { $_->[0] => 1 } my_puzzles();
    my @puz;
    while (my ($dt, $puz) = each %puzzle) {
        if (substr($puz, 0, 7) eq $seven) {
            push @puz, [ $dt, uc substr($puz, 8, 1)
                              . (     $dt eq $date? ' ' . red('*')
                                 :$is_in_list{$dt}? ' *'
                                 :                  ''
                                )
                       ];
        }
    }
    my @rows;
    for my $p (sort { $a->[0] cmp $b->[0] } @puz) {
        my $date = $p->[0];
        push @rows,
            Tr(td(qq!<span class=link onclick="new_date('$date');">!
                  . slash_date($date) . "</span>"),
               td({ class => 'lt' }, $p->[1])
              );
    }
    # also search the community puzzles
    my $s = `cd community_puzzles; grep -l "'seven' => '$seven'" *.txt`;
    for my $n ($s =~ m{(\d+)}xmsg) {
        my $cpn = "CP$n";
        my $href = do "community_puzzles/$n.txt";
        my $cur =     $date eq $cpn? ' ' . red('*')
                 :$is_in_list{$cpn}? ' *'
                 :                     '';
        push @rows,
            Tr(td(qq!<span class=link onclick="new_date('$cpn);">$cpn</span>!),
               td({ class => 'lt' }, uc $href->{center} . $cur),
              );
     }
    $message = table({ cellpadding => 2}, @rows);
    $cmd = '';
}
elsif ($cmd =~ m{\A s \s+ ([a-z]+) \s* \z}xms) {
    # search the archive for the word
    # we're searching everything after the |
    #
    my %is_in_list = map { $_->[0] => 1 } my_puzzles();
    my $word = $1;
    my @dates;
    while (my ($dt, $puz) = each %puzzle) {
        $puz =~ s{\A [^|]* [|]}{}xms;
        if ($puz =~ m{\b$word\b}xms) {
            push @dates, $dt;
        }
    }
    my @rows = map {
                   Tr(td(qq!<span class=link onclick="new_date('$_');">!
                         . slash_date($_) . "</span>"),
                      td(     $date eq $_? ' ' . red('*')
                         :$is_in_list{$_}? ' *'
                         :                 ''),
                     );
               }
               sort
               @dates
               ;
    # also search the community puzzles
    my $s = qx!cd community_puzzles; grep -l "words.*=>.*'$word'" [0-9]*.txt!;
    push @rows,
        map {
            my $cpn = "CP$_";
            Tr(td(qq!<span class=link onclick="new_date('$cpn');">!
                  . "$cpn</span>"),
               td(     $date eq $cpn? ' ' . red('*')
                  :$is_in_list{$cpn}? ' *'
                  :                   ''),
            );
        }
        sort { $a <=> $b }  # needed for the 11 vs 9 thing
        $s =~ m{(\d+)}xmsg;
    if (@rows) {
        $message = "\U$word\E:<br>" . table({ cellpadding => 2}, @rows);
    }
    $cmd = '';
}
elsif ($cmd eq 'h') {
    ++$hive;
    if ($hive == 5) {
        $hive = 1;
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A h \s* ([1-4]) \z}xms) {
    $hive = $1;
    $cmd = '';
}

# now to prepare the display the words we have found
# some subset, some order
my $order = 0;
my $same_letters = 0;
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
elsif ($cmd eq 'sl') {
    $same_letters = 1;
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
# ??? is this right???  why is it called twice?
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
                   Tr(td({ class => 'lt' }, ucfirst))
               }
               @words_found;
    $found_words = ul(table(@rows));
}
elsif ($order) {
    my @rows;
    my $prev_length = 0;
    my $words = '';
    for my $w (@words_found) {
        my $lw = length $w;
        if ($prev_length && $lw != $prev_length) {
            push @rows, Tr(td({ class => 'rt', valign => 'top' },
                              $prev_length),
                           td({ class => 'lt',
                                width => 475,
                                style => 'word-spacing:10px'
                              },
                              $words)
                          );
            $words = '';
        }
        $prev_length = $lw;
        $words .= ucfirst "$w ";
    }
    push @rows, Tr(td({ class => 'rt', valign => 'top' },
                      $prev_length),
                   td({ class => 'lt', width => 550 },
                      $words)
                  );
    $found_words = table({ cellpadding => 3 }, @rows);
}
elsif ($same_letters) {
    my %groups;
    for my $w (@found) {
        my $chars = join '', uniq_chars($w);
        push @{$groups{$chars}}, ucfirst $w;
    }
    my @rows;
    GROUP:
    for my $cs (sort keys %groups) {
        if (@{$groups{$cs}} == 1) {
            next GROUP;
        }
        push @rows, Tr(td({ valign => 'top', class => 'lt' }, $cs),
                       td({ class => 'lt', width => 550 },
                          "@{$groups{$cs}}"));
    }
    $found_words = table({ cellpadding => 2 }, @rows);
}
else {
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
        $found_words .= "$w ";
    }
    if (@found && @words_found == @found) {
        my $nwords = @found;
        $found_words .= " <span class=gray>$nwords</span>";
    }
}
$found_words = "<div class=found_words>$found_words</div>";
if (! $show_WordList) {
    $found_words = '';
}

# get the HT and TL tables ready
# $sums{$c}{1} is the rightmost column (sigma)
# $sums{1}{$l} is the bottom row       (sigma)
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

    # the summations:
    ++$sums{$c1}{1};
    ++$sums{1}{$l};
    ++$sums{1}{1};

    # and the two letter list
    ++$two_lets{$c2};
}

# how many Non-zero columns and rows?
my $ncols = 0;
for my $l (4 .. $max_len) {
    if ($sums{1}{$l} != 0) {
        ++$ncols;
    }
}
my $nrows = 0;
for my $c (@seven) {
    if ($sums{$c}{1} != 0) {
        ++$nrows;
    }
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
        add_hints(1);
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
        add_hints(1);
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
my $need_show_clue_form = 0;
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
        $need_show_clue_form = 1;
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
            $need_show_clue_form = 1;
        }
    }
    if ($need_show_clue_form) {
        $show_clue_form = <<"EOH";
<form target=_blank
      id=clues_by
      action=$log/cgi-bin/nytbee_clues_by.pl
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
elsif ($cmd eq 'id') {
    # show the $uuid so the user can save it
    # for later application with the 'ID ...' command
    $message = $uuid . " <span id=uuid class=copied></span><script>copy_uuid_to_clipboard('$uuid');</script>";
                       # a clever invisible way to invoke
                       # javascript without a user click...
    $cmd = '';
}

# the hint tables
my $hint_table = '';
if ($ht_chosen) {
    my $space = '&nbsp;' x 4;
    my @rows;
    my @th;
    my $dash = '&nbsp;-&nbsp;';
    push @th, th('&nbsp;');
    LEN:
    for my $l (4 .. $max_len) {
        if (! $show_ZeroRowCol && $sums{1}{$l} == 0) {
            next LEN;
        }
        push @th, th("$space$l");
    }
    if ($show_ZeroRowCol || $ncols > 1) {
        push @th, th("$space&nbsp;&Sigma;");
    }
    push @rows, Tr(@th);
    CHAR:
    for my $c (@seven) {
        if (! $show_ZeroRowCol && $sums{$c}{1} == 0) {
            next CHAR;
        }
        my @cells;
        push @cells, th({ class => 'lt' }, uc $c);
        LEN:
        for my $l (4 .. $max_len) {
            if (! $show_ZeroRowCol && $sums{1}{$l} == 0) {
                next LEN;
            }
            push @cells, td($sums{$c}{$l}?
                               "<span class=pointer"
                               . qq! onclick="define_ht('$c', $l);">!
                               . "$sums{$c}{$l}</span>"
                           : $dash
                          );
        }
        if ($show_ZeroRowCol || ($sums{$c}{1} != 0 && $ncols > 1)) {
            push @cells, th($sums{$c}{1} || 0);
        }
        push @rows, Tr(@cells);
    }
    if ($nrows > 1 || $show_ZeroRowCol) {
        @th = th({ class => 'rt' }, '&Sigma;');
        LEN:
        for my $l (4 .. $max_len) {
            if (! $show_ZeroRowCol && $sums{1}{$l} == 0) {
                next LEN;
            }
            push @th, th($sums{1}{$l} || $dash);
        }
        push @th, th($sums{1}{1} || 0);
        push @rows, Tr(@th);
    }
    $hint_table = table({ cellpadding => 2 }, @rows);
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
        $two_lets .= qq!<span class=pointer onclick="define_tl('$two[$i]');">!
                  .  qq!\U$two[$i]\E-$two_lets{$two[$i]}</span>!;
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

my $image = '';
if (7 <= $rank && $rank <= 9) {
    my $name = lc $ranks[$rank]->{name};
    $name =~ s{\s.*}{}xms;  # for queen bee
    $image = "<img class=image_$name src=$log/nytbee/pics/$name.jpg>";
}
my $rank_image = $show_RankImage?
        "<span class='rank_name rank$rank'>$rank_name</span>$image"
       : $rank_name;

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

$cur_puzzles{$date} = join ' ',
    $nhints, $all_pangrams, $ht_chosen,
    $tl_chosen, $rank, $score_at_first_hint,
    @found
    ;
$cur_puzzles_store{$uuid} = Dumper(\%cur_puzzles);  # the key point #2
untie %cur_puzzles_store;

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
    my $add_edit = index($puzzle_has_clues{$date}, $uuid) >= 0? 'Edit': 'Add';
    $create_add
        .= "<br><span class=link onclick='add_clues();'>$add_edit Clues</span>";
    $add_clues_form = <<"EOH";
<form target=_blank
      id=add_clues
      action=$log/cgi-bin/nytbee_mkclues.pl
      method=POST
>
<input type=hidden id=date name=date value=$date>
<input type=hidden id=found name=found value='@found'>
</form>
EOH
}

# now to display everything
# cgi-bin/style.css?

my $heading = $show_Heading? <<"EOH": '';
<div class=float-child1>
    <a target=_blank onclick="set_focus();" href='https://www.nytimes.com/subscription'>NY Times</a> Spelling Bee<br>$show_date$clues_are_present
</div>
<div class=float-child2>
     <img width=53 src=$log/nytbee/pics/bee-logo.jpg onclick="navigator.clipboard.writeText('$cgi/nytbee.pl/$date');show_copied('logo');set_focus();" class=link><br><span class=copied id=logo></span>
</div>
<div class=float-child3>
    <span class=help><a target=nytbee_help onclick="set_focus();" href='$log/nytbee/help.html'>Help</a></span><br><span class=create_add>$create_add</span>
</div>
<br><br>
EOH

my $letters = '';
my @coords;
my $let_size;
my $img_left_margin;
if ($hive == 4) {
    $letters = <<"EOH";
<pre>
     $six[0]   $six[1]
   $six[2]   <span class=red2>\U$center\E</span>   $six[3]
     $six[4]   $six[5]
</pre>
EOH
}
elsif ($hive == 1) {        # bee hive honeycomb
    $letters = "<p><img class=img src=$log/nytbee/pics/hive.jpg height=240><p>";
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
        { top => 214, left => 172, }, #0    208 168
        { top => 134, left => 172, }, #1
        { top => 175, left => 104, }, #2
        { top => 175, left => 241, }, #3
        { top => 253, left => 104, }, #4
        { top => 253, left => 239, }, #5
        { top => 295, left => 172, }, #6
    );
    # adjust an I
    for my $i (1 .. 6) {
        if ($six[$i-1] eq 'I') {
            $coords[$i]{left} += 6;
        }
    }
    if ($center eq 'i') {
        $coords[0]{left} += 6;
    }
}
elsif ($hive == 2) {        # flower
    $letters = "<p><img class=img src=$log/nytbee/pics/flower.jpg height=250><p>";
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
elsif ($hive == 3) {    # hex letters
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
if (! $show_Heading && ($hive == 1 || $hive == 2)) {
    for my $c (@coords) {
        $c->{top} -= 79;
    }
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

my $hint_table_list = '';
if ($ht_chosen && ($show_ZeroRowCol || $sums{1}{1} != 0)) {
    $hint_table_list .= <<"EOH";
<div class=float-child4>
    <div id=hint_table class=hint_table>
    $hint_table
    </div>
</div>
EOH
}
if ($tl_chosen && ($show_ZeroRowCol || $sums{1}{1} != 0)) {
    $hint_table_list .= <<"EOH";
<div class=float-child5>
    <div id=two_lets class=two_lets>
    $two_lets
    </div>
</div>
EOH
}
print <<"EOH";
<html>
<head>
<title>Spelling Bee - $show_date</title>
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
</style>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_style.css'/>
<script src="$log/nytbee/js/nytbee.js"></script>
</head>
<body>
$heading
<form id=main name=form method=POST action='$cgi/nytbee.pl'>
<input type=hidden name=date value='$date'>
<input type=hidden name=has_message value=$has_message>
<input type=hidden name=six value='@six'>
<input type=hidden name=seven_let value='@seven_let'>
<input type=hidden name=hive value=$hive>
<input type=hidden name=show_Heading value=$show_Heading>
<input type=hidden name=show_WordList value=$show_WordList>
<input type=hidden name=show_RankImage value=$show_RankImage>
<input type=hidden name=show_ZeroRowCol value=$show_ZeroRowCol>
$letters
$message
<input class=new_words
       type=text
       size=40
       id=new_words
       name=new_words
       autocomplete=off
><br>
</form>
$found_words
<p>
Score: $score $rank_image
$disp_nhints$hint_table_list
$show_clue_form$add_clues_form
</body>
<script>set_focus();</script>
</html>
EOH
