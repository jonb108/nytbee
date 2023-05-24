#!/usr/bin/perl
use strict;
use warnings;
use CGI;
use CGI::Carp qw/
    fatalsToBrowser
/;
use BeeUtil qw/
    extra_let
    ymd
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
    span
    word_score
    JON
    $log
    $cgi
    $cgi_dir
    $thumbs_up
    get_html
/;
use BeeColor qw/
    set_colors
    get_colors
/;
use BeeDBM qw/
    %end_time_for
    %uuid_ip
    %uuid_screen_name
    %screen_name_uuid
    %num_msgs
    %puzzle
    %cur_puzzles_store
    %puzzle_has_clues
    %osx_usd_words_47
    %osx_usd_words_48
    %first_appeared
    %definition_of
    %message_for
    %uuid_colors_for
/;
use SvgHex qw/
    svg_hex
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
use File::Slurp qw/
    append_file
    write_file
    read_file
/;

my $message = '';
my $ymd = ymd();
my $q = CGI->new();
my $hive = $q->param('hive') || $q->cookie('hive') || 1;
my $hive_cookie = $q->cookie(
    -name    => 'hive',
    -value    => $hive,
    -expires => '+20y',
);
my $uuid = cgi_header($q, $hive_cookie);
my $uuid11 = substr($uuid, 0, 11);
my %params = $q->Vars();

sub now_secs {
    my ($second, $minute, $hour) = (localtime)[0 .. 2];
    --$hour;    # west coast time
    return 60*60*$hour + 60*$minute + $second;
}

my $end_time = $end_time_for{$uuid11};
if ($end_time) {
    my $now = now_secs();
    if ($end_time =~ m{\A [+](\d+)}xms) {
        my $secs_left = $1;
        $end_time_for{$uuid11} = $now + $secs_left;
    }
    else {
        # is their time up?
        if ($now >= $end_time) {
            $message = "Your self-imposed time limit has arrived. &#128542;<br>"
                     . "Tomorrow is another day. &#128522;";
            $params{new_words} = '';
            $params{hidden_new_words} = '';
        }
    }
}
if ($params{new_words} =~ m{\A \s* idk? \s+}xmsi) {
    # we took care of this case in cgi_header
    $params{new_words} = '';
}
# search for 'id' below

$uuid_ip{$uuid} = $ENV{REMOTE_ADDR};

my $screen_name = '';
if (exists $uuid_screen_name{$uuid11}) {
    $screen_name = $uuid_screen_name{$uuid11};
}

my $mobile = $ENV{HTTP_USER_AGENT} =~ m{iPhone|Android}xms;
#$mobile = 1;
my $focus = $mobile? '': 'set_focus();';

#
# DR
# no cycle - no need for cycle graphic on mobile site
#       just Enter with blank text field
# .dr - for absolute placement
# for define random...
# LE, DB, use SVG graphics for hexagon - or what pangram haiku does
#                                      - might be better
# let Aruna, Navin, Denise know?
#   maybe they have forgiven?   not exonerated but forgiven?
# clicking is ok if not mobile
# describe and show the mobile settings
# DB or FT? FT = first time
# DB - which words in current puzzle are debuting?
# DB abcd - when did abcd debut?
# DB 4/5/19 - what words debuted on this date?
# GAB GP GB4 'G Y' - give up and add to the found list
# add comment about Shun's word analysis
#   sbsolver.com = linked to from shunn.net
#   his hints are nice - but you need to switch
#   to his site.
#   his grid is also not dynamic...
#   some cool effects in the grid but no hints
#       on individual words like reveal or define
#       nice to click on 2 letter entries and get 3 letter tallies
# get his early puzzles
# nytbee.com ends at 7/29/18
# mine ends at 5/29/18  sbsolver.com goes back further to 5/9/18
# We are 'toiling in the same field'.
#
# when solving today's puzzle - recommend a subscription?
#
# make the nyt_puzzles.txt file downloadable!
#

my %cur_puzzles;
my $s = $cur_puzzles_store{$uuid};
if ($s) {
    %cur_puzzles = %{ eval $s };    # the key point #1 (see below for #2)
}
# otherwise this is a brand new user...

sub log_it {
    my ($msg) = @_;
    append_file "beelog/$ymd", substr($uuid, 0, 11) . " = $msg\n";
}
sub add_3word {
    my ($type, $date, $w) = @_;
    append_file("$type/$date",  "$w\n");
}

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

sub cp_message {
    my ($cp_href, $n) = @_;
    my $mess = '';
    if ($cp_href->{title}) {
        $mess .= "$cp_href->{title}";
    }
    if ($cp_href->{description}) {
        my $s = $cp_href->{description};
        $s =~ s{[<][^>]*[>]}{}xms;  # no HTML tags, please
        $s =~ s{\n\n}{<p>}xms;
        $s =~ s{[*](\S+)[*]}{<b>$1</b>}xms;
        $s =~ s{[_](\S+)[_]}{<u>$1</u>}xms;
        $s =~ s{(\S+@[a-z.]+)}{<a href="mailto:$1?subject=CP$n">$1</a>}xmsi;
        $mess .= "<p>$s";
    }
    if ($mess) {
        $mess = "<div class=description>$mess</div>";
    }
    return $mess;
}

sub puzzle_class {
    my ($n) = @_;
    return $n <= 25? 'Small'
          :$n <= 50? 'Medium'
          :$n <= 75? 'Large'
          :          'Jumbo';
}

my $comm_dir = 'community_puzzles';
my ($seven, $center, @pangrams);
my $Center;
my @seven;
my @ok_words;
my %clue_for;

# see sub load_nyt_clues
my %nyt_clues_for;        # key is word,
                          # value is [ { person_id => x, clue => y }, ... ]
my %nyt_cluer_name_of;    # key is person_id
my %nyt_cluer_color_for;  # key is person_id

my $first = date('5/9/18');
my $date;
my $today = my_today();
my $new_puzzle = 0;
my $path_info = uc substr $q->path_info(), 1;   # no need for the leading /
                                                # it is either yyyymmdd or CPx

# Puzzle from which date are we dealing with?
# This is Very confusing, hacky, kludgy, and messy.
# Thorough testing is critical!
#
# content of $params{new_words} => $cmd
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
my $cmd = lc($params{hidden_new_words} || $params{new_words});
    # $cmd is all in lower case
    # even though it looks like we are typing upper case...
    #
$cmd = trim($cmd);
log_it($cmd) if $cmd;

# is there a 'message of the day' that the user
# has not yet seen?
# disabled for now ...
if (! $cmd) {
    if ($message_for{$uuid}) {
        my ($n, $date) = split ' ', $message_for{$uuid};
        ++$n;
        if (-f "messages/$n") {
            # there IS another message the user should see
            # but has at least one day passed since they saw
            # the last message?
            $date = date($date);
            if ($date < $today) {
                # yes.
                $message .= read_file("messages/$n");
                $message_for{$uuid} = "$n " . $today->as_d8();
            }
        }
    }
    else {
        # this user has seen no messages at all
        # and needs to see the first message
        $message_for{$uuid} = "1 " . $today->as_d8();
        $message .= read_file("messages/1");
    }
}

my $show_Heading    = exists $params{show_Heading}?
                             $params{show_Heading}: !$mobile;
my $show_WordList   = exists $params{show_WordList}?
                             $params{show_WordList}: 1;
my $show_BingoTable = exists $params{show_BingoTable}?
                             $params{show_BingoTable}: 0;
my $bonus_mode      = exists $params{bonus_mode}?
                             $params{bonus_mode}: 0;
my $forum_mode      = exists $params{forum_mode}?
                             $params{forum_mode}: 0;
my $show_RankImage  = exists $params{show_RankImage}?
                             $params{show_RankImage}: 1;
my $show_GraphicStatus = exists $params{show_GraphicStatus}?
                             $params{show_GraphicStatus}: 0;

my $forum_post_to_edit = 0;

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
# initial guess at what puzzle we are looking at
$date = $path_info;
if (!$date || $date !~ m{\A \d{8} | CP\d+ \z}xms) {
    $date = $params{date};      # hidden field
}
if (! $date) {
    # today
    $date = $today->as_d8();
    $new_puzzle = 1;
}

my $post = $params{forum_post};
if ($cmd eq '' && $post) {
    check_screen_name();
    $post =~ s{\A \s*|\s* \z}{}xmsg;
    $post =~ s{\n\n}{<p>}xmsg;
    $post =~ s{\n}{<br>}xmsg;
    $post =~ s{"}{&#34;}xmsg;
    if ($post) {    # is anything there?
        system(qq!$cgi_dir/get_post.pl $date "$screen_name" "$post"!);
    }
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
                $message .= "Illegal range: $start-$end";
                $cmd = '';
            }
            else {
                push @nums, $start .. $end;
            }
        }
        else {
            $message .= "Illegal puzzle numbers: $nums";
            $cmd = '';
        }
    }
    my @puzzles = my_puzzles();
    if (@nums) {
        my $npuzzles = @puzzles;
        for my $n (@nums) {
            if ($n > $npuzzles) {
                $message .= "$n: There are only $npuzzles current puzzles";
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
    my $fname = "$comm_dir/$ncp.txt";
    if (! -f $fname) {
        $message .= "CP$ncp: No such Community Puzzle";
    }
    else {
        my $href = do $fname;
        if ($href->{uuid} ne $uuid) {
            $message .= ul(red("You did not create CP$ncp."));
        }
        else {
            unlink $fname;
            # and just in case it is in the current list...
            delete $cur_puzzles{"CP$ncp"};
            $message .= ul "Deleted CP$ncp";
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
        $message .= "Not that many puzzles";
    }
    else {
        my $puz_id = $puzzles[$puz_num-1][0];
        if ($puz_id =~ m{\A \d}xms) {
            $date = $puz_id;
        }
        else {
            # we have lower case cp
            # but we need CP
            # CP\d+
            $date = uc $puz_id;
        }
    }
    $cmd = '';
}
elsif ($cmd eq 'nr') {
    # random date since $first
    my $ndays = $today - $first + 1;
    $date = $first + int(rand $ndays);
    $date = $date->as_d8();
    $new_puzzle = 1;
    $cmd = '';
}
elsif ($cmd eq 'nrb') {
    open my $in, '<', 'bingo_dates.txt';
    my @dates = <$in>;
    close $in;
    $date = $dates[ rand @dates ];
    chomp $date;
    $new_puzzle = 1;
    $cmd = '';
}
elsif (my ($cp_num) = $cmd =~ m{\A cp \s* (\d+) \z}xms) {
    my $fname = "$comm_dir/$cp_num.txt";
    if (! -f $fname) {
        $message .= "CP$cp_num: No such Community Puzzle";
        $cmd = 'nooop';
    }
    else {
        my $cp_href = do $fname;
        if ($cp_href->{publish} ne 'yes') {
            $message .= "CP$cp_num: No such Community Puzzle";
            $cmd = 'nooop';
        }
        else {
            $date = "CP$cp_num";
            $message .= cp_message($cp_href, $cp_num);
            $new_puzzle = 1;
            $cmd = '';
        }
    }
}
elsif ($cmd eq 't') {
    $date = $today->as_d8();
    $new_puzzle = 1;
    $cmd = '';
}
elsif ($cmd eq 'y') {
    $date = ($today-1)->as_d8();
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
elsif (   $cmd ne '1'
       && $cmd ne '2'
       && $cmd ne '52'
       && $cmd ne '51'
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
            $message .= "Illegal date: $new_date";
            $cmd = 'nooop';
        }
    }
    else {
        $message .= "Illegal date: $new_date";
        $cmd = 'nooop';
    }
}

# hack... :(
if (! $message && $path_info =~ m{cp(\d+)}xmsi) {
    my $n = $1;
    my $fname = "$comm_dir/$n.txt";
    my $cp_href = do $fname;
    $message .= cp_message($cp_href, $n);
    $cmd = '';
}

my $show_date;
my $clues_are_present = '';
my $cp_href;

sub no_puzzle {
    my ($p) = @_;
    print "$p: Sorry, no such puzzle.";
    exit;
}

# we have a valid date. either d8 format or CP#
if ($date =~ m{\A\d}xms) {
    # d8 get the puzzle data from NYT Puzzles
    $show_date = date($date);
    if (! $show_date) {
        no_puzzle $date;
    }
    $show_date = $show_date->format("%B %e, %Y");
    my $puzzle = $puzzle{$date};
    if (! $puzzle) {
        no_puzzle $show_date;
    }
    if ($puzzle_has_clues{$date}) {
        $clues_are_present = " <span class=red2>*</span>";
    }

    my ($s, $t) = split /[|]/, $puzzle;
    ($seven, $center, @pangrams) = split ' ', $s;
    $Center = uc $center;
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
    if (! -f $fname) {
        no_puzzle $date;
    }
    $cp_href = do $fname;
    if ($cp_href->{publish} ne 'yes') {
        no_puzzle $date;
    }
    $seven = $cp_href->{seven};
    @seven = split //, $seven;
    $center = $cp_href->{center};
    $Center = uc $center;
    @pangrams = @{$cp_href->{pangrams}};
    @ok_words = @{$cp_href->{words}};
    %clue_for = %{$cp_href->{clues}};
}
my $nwords = @ok_words;
my $letter_regex = qr{([^$seven])}xms;  # see sub check_word
my $no_def = qr{No\s+definition}xms;
my $npangrams = @pangrams;

# get ready for hive == 2 (seven straight letters)
my @seven_let;
if ($params{seven_let} && $date eq $params{date}) {
    @seven_let = split ' ', $params{seven_let};
}
else {
    @seven_let = map { uc } shuffle @seven;
}

my %is_pangram = map { $_ => 1 } @pangrams;
my %is_ok_word = map { $_ => 1 } @ok_words;     # the curated accepted word list
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

if ((! $cmd || $cmd eq 'nooop') && ! $params{has_message}) {
    # We hit Return in an empty text field so
    # there is no command
    # and we didn't hit Return simply to clear a message
    # shuffle the @six and @seven_let
    @six = shuffle(@six);
    @seven_let = shuffle(@seven_let);
}
if ($cmd eq 'nooop') {
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

my (@found,     # includes valid puzzle words, lexicon+ words, donut- words
    $nhints,
    $ht_chosen,
    $tl_chosen,
    $score_at_first_hint,
    $score,
    $rank_name,
    $rank);

sub add_hints {
    my ($n) = @_;
    if ($n > 0 && $score_at_first_hint < 0) {
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
my %is_found = map {
                   my $x = $_;
                   $x =~ s{[*+-]\z}{}xms;
                   $x => 1;
               }
               @found;

sub compute_score_and_rank {
    $score = 0;
    WORD:
    for my $w (@found) {
        next WORD if $w =~ m{[*+-] \z}xms;   # donut, lexicon
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

# a simple definition
#
# fullword is true only if we have given the entire word
# like 'd juice'
# and not dp, dx1, dx, or dxy
#
# if fullword we don't tally hints and we don't mask the word
sub define {
    my ($word, $fullword, $clue_plus) = @_;

    my $def = '';
    # a Community Puzzle clue
    if (!$fullword && exists $clue_for{$word}) {
        $def .= "<li style='list-style-type: circle'>$clue_for{$word}</li>\n";
    }
    # community contributed NYT Bee Puzzle clues
    if ((! $def || $fullword) && exists $nyt_clues_for{$word}) {
        for my $href (@{$nyt_clues_for{$word}}) {
            $def .= "<li style='list-style-type: circle'>"
                 .  "<span style='color:"
                 .  "$nyt_cluer_color_for{$href->{person_id}}'>"
                 .  $href->{clue}
                 .  "</span>"
                 .  "</li>\n"
                 ;
        }
        # just one word but perhaps several hints for that word
    }
    if (! exists $definition_of{$word}) {
        # put this in BeeUtil???
        my $html = get_html("https://www.wordnik.com/words/$word");
        my ($def1) = $html =~ m{[<]meta\s content='$word:\ ([^']*)'}xms;
        if ($def1) {
            $def1 =~ s{[<][^>]*[>]}{}xmsg;
            $def1 =~ s{[&][#]39;}{'}xmsg;
            $def1 =~ s{$word}{'*' x length($word)}xmsegi;
            $def1 =~ s{[^[[:ascii]]]}{}xmsg;
            eval { $definition_of{$word} = $def1; };
            if ($@) {
                # try this:
                $def1 =~ s{:.*}{.}xms;
                eval { $definition_of{$word} = $def1; };
            }
        }
    }
    if ((!$def || $clue_plus) && exists $definition_of{$word}) {
        my $s = $definition_of{$word};
        if ($fullword) {
            # undo an earlier masking
            $s =~ s{[*]{2,}}{$word}xmsg;
        }
        if ($def) {
            $def .= "<li>$s</li>";
        }
        else {
            $def .= $s;
        }
    }
    if (! $def) {
        $def = 'No definition';
    }
    return "<span class=letter>" . ucfirst($def) . "</span>";
}

sub do_define {
    my ($term, $plus) = @_;

    load_nyt_clues;
    my $msg = '';
    my $line = "&mdash;" x 4;
    if ($term eq 'p') {
        my $npangrams =  0;
        for my $p (grep { !$is_found{$_} } @pangrams) {
            ++$npangrams;
            my $def = define($p, 0, $plus);
            add_hints(3) unless $def =~ $no_def;
            if ($def) {
                $msg .= ul($def) . '--';
            }
        }
        $msg =~ s{--\z}{}xms;
        $msg =~ s{--}{$line<br>}xmsg;
        if ($msg) {
            my $pl = $npangrams == 1? '': 's';
            $msg = "Pangram$pl:$msg";
        }
        $cmd = '';
    }
    elsif ($term eq 'r') {
        # a random word that has not yet been found
        my @words = grep { !$is_found{$_} }
                    @ok_words;
        if (! @words) {
            $msg .= 'No more words.';
        }
        else {
            $msg .= define($words[ rand @words ], 0, $plus);
            add_hints(1) unless $msg =~ $no_def;
        }
        $cmd = '';
    }
    elsif ($term eq '5') {
        my @words = grep { !$is_found{$_} && length >= 5 }
                    @ok_words;
        if (! @words) {
            $msg .= 'No more 5+ letter words.';
        }
        else {
            $msg .= define($words[ rand @words ], 0, $plus);
            add_hints(1) unless $msg =~ $no_def;
        }
        $cmd = '';
    }
    elsif ($term =~ m{\A ([a-z])(\d+) \z}xms) {
        my $let = $1;
        my $len = $2;
        if (index($seven, $let) < 0) {
            $msg .= ul(red(uc $cmd) . ": \U$let\E is not in \U$seven");
        }
        else {
            $msg = '';
            for my $w (get_words($let, $len)) {
                my $def = define($w, 0, $plus);
                add_hints(3) unless $def =~ $no_def;
                if ($def) {
                    $msg .= ul($def) .  '--';
                }
            }
            $msg =~ s{--\z}{}xms;
            $msg =~ s{--}{$line<br>}xmsg;
            if ($msg) {
                $msg = "\U$term\E:<br>$msg";
            }
        }
        $cmd = '';
    }
    elsif ($term =~ m{\A ([a-z][a-z]) \z}xms) {
        my $lets = $1;
        if ($lets =~ $letter_regex) {
            $msg .= ul(red(uc $cmd) . ": \U$1\E is not in \U$seven");
        }
        else {
            $msg .= '';
            for my $w (get_words($lets)) {
                my $def = define($w, 0, $plus);
                add_hints(3) unless $def =~ $no_def;
                if ($def) {
                    $msg .= ul($def) . '--';
                }
            }
            $msg =~ s{--\z}{}xms;
            $msg =~ s{--}{$line<br>}xmsg;
            if ($msg) {
                $msg = "\U$term\E:<br>$msg";
            }
        }
        $cmd = '';
    }
    $message = $msg;
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
    my $msg = '';
    if ($term eq 'p') {
        for my $p (grep { ! $is_found{$_} } @pangrams) {
            $msg .= reveal($p, $nlets, $end);
        }
    }
    elsif (my ($first, $len) = $term =~ m{\A ([a-z])(\d+)}xms) {
        if ($first =~ $letter_regex) {
            $msg .= ul(red(uc $cmd) . ": \U$first\E is not in \U$seven");
            $err = 1;
        }
        else {
            if ($nlets == 1) {
                # silently gnore
            }
            else {
                for my $w (get_words($first, $len)) {
                    $msg .= reveal($w, $nlets, $end);
                }
            }
        }
    }
    else {
        # $term is two letters
        if ($term =~ $letter_regex) {
            $msg .= ul(red(uc $cmd) . ": \U$1\E is not in \U$seven");
            $err = 1;
        }
        else {
            if ($nlets == 1 || (! $end && $nlets == 2)) {
                # silently ignore
            }
            else {
                for my $w (get_words($term)) {
                    $msg .= reveal($w, $nlets, $end);
                }
            }
        }
    }
    if (!$err && $msg) {
        $message .= "\U$cmd\E:" . ul($msg);
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
elsif ($cmd eq 'bt') {
    $show_BingoTable = ! $show_BingoTable;
    $cmd = '';
}
elsif ($cmd eq 'bn') {
    $bonus_mode = ! $bonus_mode;
    $cmd = '';
}
elsif ($cmd =~ m{\A fx \s* (\d+) \z}xms) {
    my $id = $1;
    system("$cgi_dir/del_post.pl $id '$screen_name'");
    if ($num_msgs{$date} > 0) {
        --$num_msgs{$date};
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A fe \s* (\d+) \z}xms) {
    $forum_post_to_edit = $1;
    $cmd = '';
}
elsif ($cmd eq 'f') {
    $forum_mode = ! $forum_mode;
    $cmd = '';
}
elsif ($cmd eq 'im') {
    $show_RankImage = ! $show_RankImage;
    $cmd = '';
}
elsif ($cmd eq 'st') {
    $show_GraphicStatus = ! $show_GraphicStatus;
    $cmd = '';
}
# do we have a reveal command?
elsif (my ($ev, $nlets, $term)
    = $cmd =~ m{
        \A ([ev])\s*(\d+)\s*(p|[a-z]\d+|[a-z][a-z]) \z
      }xms
) {
    do_reveal($ev, $nlets, $term);
    $cmd = '';
}
elsif ($cmd =~ m{\A r\s* (%?) \z}xms) {
    my $percent = $1;
    my $ndonut_lexicon_bonus = grep { m{[*+-]\z}xms } @found;
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
                    my $m = @ok_words - @found + $ndonut_lexicon_bonus;
                    my $pl = $m == 1? '': 's';
                    $more .= ", $m more word$pl";
                }
            }
            $cols .= td(red('*') . $more);
        }
        $rows .= Tr($cols);
    }
    $message .= ul(table({ cellpadding => 4}, $rows));
    $cmd = '';
}
elsif ($cmd =~ m{\A (d[+]?)(p|r|5|[a-z]\d+|[a-z][a-z]) \z}xms) {
    my $Dcmd = $1;
    my $term = $2;
    do_define($term, $Dcmd eq 'd+');
    $cmd = '';
}
elsif (my ($gt, $item) = $cmd =~ m{\A \s* [#] \s*([>]?)(\d*|[a-z]?) \s* \z}xms) {
    my @words = grep { !$is_found{$_} }
                @ok_words;
    if (! $item) {
        $message .= scalar(@words);
    }
    elsif ($item =~ m{\A\d+\z}xms) {
        my $n = grep { $gt? length > $item: length == $item } @words;
        $message .= $n . '<br>';
            # not sure why we need the <br>
    }
    else {
        my $n = grep { m{\A$term}xms } @words;
        $message .= $n . '<br>';
    }
    $cmd = '';
    add_hints(1);
}
elsif ($cmd =~ m{\A d \s+ ([a-z ]+) \z}xms) {
    # dictionary definitions of full words not clues
    my $words = $1;
    my @words = split ' ', $words;
    for my $word (@words) {
        $message .= qq!<br><span class=cursor_black onclick="full_def('$word');"><span class=letter>\U$word</span>:!
                 .  ul(define($word, 1, 0))
                 .  '</span>'
                 ;
    }
    $message =~ s{\A <br>}{}xms;
    $cmd = '';
}
elsif ($cmd =~ m{\A g \s+ yp? \z}xms) {
    my @words = grep { !$is_found{$_} }
                @ok_words;
    if ($cmd =~ /p/) {
        $cmd = "@words";
        # as if they typed them...
    }
    else {
        @words = map {
                     $is_pangram{lc $_}? color_pg($_): $_
                 }
                 map { ucfirst }
                 sort
                 @words;
        if (@words) {
            $message .= "<p class=mess>@words";
        }
        $cmd = '';
    }
    add_hints(@words * 5);
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
    FOUND:
    for my $w (@found) {
        my $x = $w;
        if ($x =~ s{([*+-])\z}{}xms) {
            push @rows, Tr(td({ class => 'gray' }, ucfirst $x),
                           td(''),
                           td(''),
                           td({ class => 'lt gray' },
                              $space
                              . {
                                   '*' => 'Bonus',
                                   '+' => 'Lexicon',
                                   '-' => 'Donut',
                                }->{$1}
                             )
                        );
            next FOUND;
        }
        else {
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
        }
        if ($tot == $score_at_first_hint) {
            # yes == above
            push @rows, Tr(td({ colspan => 3 }, '<hr>'));
        }
    }
    $message .= table({ cellpadding => 2 }, @rows);
    my $ndonut_lexicon_bonus = grep { m{[*+-]\z}xms } @found;
    my $more = @ok_words - (@found - $ndonut_lexicon_bonus);
    my $pl = $more == 1? '': 's';
    $message .= "<p> $more more word$pl to find";
    $cmd = '';
}
elsif (my ($pat) = $cmd =~ m{\A lcp \s*(\S*) \z}xms) {
    my $max = 5;
    if ($pat =~ m{\A (\d+) \z}xms) {
        $max = $pat;
        $pat = '';
    }
    elsif ($pat) {
        $max = 9999;
    }
    my $s = `cd $comm_dir; ls -tr1 [0-9]*.txt`;
    my @rows;
    my $title_row = Tr(th('&nbsp;'),
                       th(''),
                       th({ class => 'lt' }, 'Name'),
                       th({ class => 'lt' }, 'Seven'),
                       th('Center'),
                       th({ class => 'lt' }, 'Title'),
                    );
    my %is_in_list = map { $_->[0] => 1 } my_puzzles();
    CP:
    for my $n (sort { $b <=> $a }
               $s =~ m{(\d+)}xmsg
    ) {
        my $href = do "$comm_dir/$n.txt";
        if ($href->{publish} ne 'yes') {
            next CP;
        }
        if ($pat && $href->{name} !~ m{$pat}xmsi) {
            next CP;
        }
        my $cpn = "CP$n";
        push @rows, Tr(td({ class => 'rt' },
                          qq!<span class=link onclick="issue_cmd('$cpn');">!
                          . "$cpn</span>"),
                       td(     $date eq $cpn? red('*')
                          :$is_in_list{$cpn}? '*'
                          :                   ''),
                       td({ class => 'lt' }, $href->{name}),
                       td({ class => 'lt' }, uc $href->{seven}),
                       td({ class => 'cn' }, uc $href->{center}),
                       td({ class => 'lt' }, $href->{title}),
                    );
        if (@rows >= $max) {
            last CP;
        }
    }
    if (@rows) {
        $message .= table({ cellpadding => 3 }, $title_row, @rows);
    }
    $cmd = '';
}
elsif ($cmd eq 'ycp') {
    my $s = `cd $comm_dir; grep -l '$uuid' *.txt`;
    my @nums = sort { $b <=> $a }
               $s =~ m{(\d+)}xmsg;
    my @rows;
    for my $n (@nums) {
        my $href = do "$comm_dir/$n.txt";
        my @pangrams = map { ucfirst } @{$href->{pangrams}};
        push @rows, Tr(td("<a target=nytbee onclick='set_focus();'"
                        . " href='$log/cgi-bin/edit_cp.pl/$n'>CP$n</a>"),
                       td(slash_date($href->{created})),
                       td({ class => 'lt' }, @pangrams),
                    );
    }
    $message .= "Your Community Puzzles:<p>"
             . table({ cellpadding => 5 }, @rows);
    $cmd = '';
}
elsif ($cmd eq 'l') {
    my $n = 1;
    my $msg = '';
    for my $p (my_puzzles()) {
        my $cur = $p->[0] eq $date? '*': '';
        my $pg  = $p->[1]? '&nbsp;&nbsp;<span class=green>p</span>': '';
        $msg .= Tr(
                       td($n),
                       td($cur),
                       td({ class => 'lt' }, 
                      qq!<span class=link onclick="issue_cmd('$p->[0]');">!
                          . slash_date($p->[0])
                          . "<span>"),
                      td({ class => 'lt' }, $ranks[$p->[2]]->{name}),
                      td($pg)
                    );
        ++$n;
    }
    $message .= table({ cellpadding => 4}, $msg);
    $cmd = '';
}
elsif ($cmd eq 'cl') {
    my %is_in_list = map { $_->[0] => 1 } my_puzzles();
    my @dates = `$cgi_dir/nytbee_clue_dates.pl $uuid`;
    chomp @dates;
    if (!@dates) {
        $message .= '';
    }
    else {
        $message
            = 'Puzzles you clued:<br>'
            . table(
                  map {
                      Tr(td(qq!<span class=link onclick="issue_cmd('$_');">!
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
elsif ($cmd eq 'f7') {
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
            Tr(td(qq!<span class=link onclick="issue_cmd('$date');">!
                  . slash_date($date) . "</span>"),
               td({ class => 'lt' }, $p->[1])
              );
    }
    # also search the community puzzles
    my $s = `cd $comm_dir; grep -l "'seven' => '$seven'" *.txt`;
    for my $n ($s =~ m{(\d+)}xmsg) {
        my $cpn = "CP$n";
        my $href = do "$comm_dir/$n.txt";
        my $cur =     $date eq $cpn? ' ' . red('*')
                 :$is_in_list{$cpn}? ' *'
                 :                     '';
        push @rows,
            Tr(td(qq!<span class=link onclick="issue_cmd('$cpn');">$cpn</span>!),
               td({ class => 'lt' }, uc $href->{center} . $cur),
              );
     }
    $message .= table({ cellpadding => 2}, @rows);
    $cmd = '';
}
elsif ($cmd =~ m{\A ft \s+ ([a-z]+) \z}xms) {
    my $word = $1;
    # when did this word first appear?
    my $dt = $first_appeared{$word};
    if ($dt) {
        $message .= qq!<span class=link onclick="issue_cmd('$dt');">!
                 . slash_date($dt)
                 . '</span>'
                 ;
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A s \s+ ([a-z]+) \z}xms) {
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
                   Tr(td(qq!<span class=link onclick="issue_cmd('$_');">!
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
    my $s = qx!cd $comm_dir; grep -l "words.*=>.*'$word'" [0-9]*.txt!;
    push @rows,
        map {
            my $cpn = "CP$_";
            Tr(td(qq!<span class=link onclick="issue_cmd('$cpn');">!
                  . "$cpn</span>"),
               td(     $date eq $cpn? ' ' . red('*')
                  :$is_in_list{$cpn}? ' *'
                  :                   ''),
            );
        }
        sort { $a <=> $b }  # needed for the 11 vs 9 thing
        $s =~ m{(\d+)}xmsg;
    if (@rows) {
        $message .= "\U$word\E:<br>" . table({ cellpadding => 2}, @rows);
    }
    $cmd = '';
}
elsif ($cmd eq 'h') {
    ++$hive;
    if ($hive == 4) {
        $hive = 1;
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A h \s* ([1-3]) \z}xms) {
    $hive = $1;
    $cmd = '';
}
elsif ($cmd =~ m{\A le \s+ (\S{6}) \s* \z}xms) {
    # $1 is oooooo (all 6 outer letters)
    my @lets = split //, uc $1;
    my $six = join '', sort @six;
    my $new = join '', sort @lets;
    if ($six ne $new) {
        $message .= "$new != $six";
        $cmd = '';
    }
    else {
        @six = @lets;
        @seven_let = (@lets, $Center);
        $cmd = '';
    }
}

# now to prepare to display the words we have found
# some subset, some order
my $order = 0;
my $same_letters = 0;
my $first_time = 0;
my $prefix = '';
my $pattern = '';
my $limit = 0;
my @words_found;
my @found_puzzle_words = grep { !m/[*+-]\z/xms } @found;
my $word_col = 0;
my $order_found = 0;
my $w_cmd = '';
if ($cmd eq 'w') {
    @words_found = @found_puzzle_words;
    $order_found = 1;
    $cmd = '';
}
elsif ($cmd eq '1w') {
    $word_col = 1;
    @words_found = sort @found_puzzle_words;
    $w_cmd = $cmd;
    $cmd = '';
}
elsif (($pattern) = $cmd =~ m{\A w!? \s* / \s* .* \z}xms) {
    @words_found = restrict($cmd, \@found_puzzle_words);
    $w_cmd = $cmd;
    $cmd = '';
}
elsif ($cmd =~ m{\A w \s* ([<>]) \s* \d*\z}xms) {
    @words_found = restrict($cmd, \@found_puzzle_words);
    $w_cmd = $cmd;
    $cmd = '';
}
elsif ($cmd =~ m{\A w \s* \d+ \z}xms) {
    @words_found = restrict($cmd, \@found_puzzle_words);
    $w_cmd = $cmd;
    $cmd = '';
}
# must have space for W prefix command
elsif ($cmd =~ m{\A w \s+ [a-z]+}xms) {
    @words_found = restrict($cmd, \@found_puzzle_words);
    $w_cmd = $cmd;
    $cmd = '';
}
elsif ($cmd eq 'sl') {
    $same_letters = 1;
    $cmd = '';
}
elsif ($cmd =~ m{\A lm \s*(\d*) \z}xms) {
    my $mins_more = $1;
    my $now = now_secs();
    my $end = $end_time_for{$uuid11};
    if ($end) {
        if (! $mins_more) {
            # they want to know how much more time they have
            my $n = $end - $now;
            my $m = int($n / 60);
            my $s = $n % 60;
            $message = sprintf "%d:%02d left", $m, $s;
        }
        else {
            $message = "You already set a time limit for today.";
        }
    }
    elsif ($mins_more) {
        my $new_time = $now + 60*$mins_more;
        if ($new_time >= 24*60*60) {
            # at 23:55 the person issued the command "LM 10".
            # the expiration time would be after midnight
            # at which time the limits are cleared so we
            # clear their limit now.
            delete $end_time_for{$uuid11};
            $message = "Your end time would be after midnight!";
            # what else to say or do?
        }
        else {
            $end_time_for{$uuid11} = $new_time;
        }
    }
    else {
        $message = "You can play as long as you'd like!";
    }
    $cmd = '';
}
elsif ($cmd eq 'pa') {
    my $end = $end_time_for{$uuid11};
    if ($end) {
        my $n = $end - now_secs();
        my $m = int($n / 60);
        my $s = $n % 60;
        $end_time_for{$uuid11} = "+$n";
        $message = sprintf "Paused.&nbsp;&nbsp;%d:%02d left", $m, $s;
    }
    else {
        $message = 'There was no time limit in place.';
    }
    $cmd = '';
}
elsif ($date !~ m{\A CP}xms && $cmd eq 'lg') {
    my $uuid11 = substr($uuid, 0, 11);
    $message = `$cgi_dir/nytbee_log.pl $date '$uuid11'`;
    $cmd = '';
}
elsif ($date !~ m{\A CP}xms && $cmd eq 'ac') {
    if ($date < '20221222') {
        $message = 'Activity monitoring began on December 22, 2022.';
    }
    else {
        $message = `$cgi_dir/nytbee_activity.pl $date`;
    }
    $cmd = '';
}
elsif ($cmd eq 'ft') {
    $first_time = 1;
    $cmd = '';
}
elsif (($uuid eq 'sahadev108!')
       && (my ($mode, $cp_num)
              = $cmd =~ m{\A ([+][+]|[-][-])cp(\d+) \z}xms)
) {
    my $fname = "$comm_dir/$cp_num.txt";
    if (! -f $fname) {
        $message .= "No such community puzzle: CP$cp_num";
    }
    else {
        my $cp_href = do $fname;
        $cp_href->{recommended} = $mode eq '++'? 1: 0;
        write_file $fname, Dumper($cp_href);
        $message .= 'Got it';
    }
    $cmd = '';
}
elsif ($cmd eq 'rcp') {
    my $s = `cd $comm_dir; grep -l "'recommended' => 1" [0-9]*.txt`;
    my @puzzles = sort {
                      lc $a->{name} cmp lc $b->{name}
                  }
                  map {
                      my $cp_href = do "$comm_dir/$_.txt";
                      my $nwords = @{$cp_href->{words}};
                      {
                          n      => $_,
                          name => $cp_href->{name},
                          title => $cp_href->{title},
                          clues => scalar(keys %{$cp_href->{clues}}),
                          nwords => $nwords,
                      }
                  }
                  $s =~ m{(\d+)}xmsg;
    my $msg = '';
    $msg .= Tr(
                   th('&nbsp;'),
                   th({class => 'lt'}, 'Name'),
                   th({class => 'lt'}, 'Title'),
                   th('Size'),
                   th('Clues'),
               );
    for my $p (@puzzles) {
        $msg .= Tr(
                        td({class => 'lt'}, qq!<span class=link onclick="issue_cmd('cp$p->{n}')">CP$p->{n}</span>!),
                        td({class => 'lt'}, $p->{name}), 
                        td({class => 'lt'}, $p->{title}), 
                        td(puzzle_class($p->{nwords})),
                        td({class => 'cn'}, $p->{clues}? '<span style="color: green; font-size: 20pt">&check;</span>': ''),
                    );
    }
    $message .= table({ cellpadding => 3 }, $msg);
    $cmd = '';
}

# so we have dealt with the various commands. (not really...)
# except for 1, 2, and a few others.
# what new words might we have instead?
my @new_words;
# this is awkward --- needs refactoring!
if (   $cmd ne '1'
    && $cmd ne '2'
    && $cmd ne '51'
    && $cmd ne '52'
    && $cmd ne 'id'
    && $cmd !~ m{\A n?[dlb]w \z}xms
    && $cmd ne 'abw'
    && $cmd ne 'i'
    && $cmd !~ m{\A cw\s*\d* \z}xms
    && $cmd !~ m{\A m\d* \z}xms
    && $cmd !~ m{\A sn\b }xms
    && $cmd !~ m{\A co\b }xms
    && $cmd !~ m{\A ([+][+]|[-][-])cp }xms
) {
    # what about $cmd eq 'i' or bw or ... ?
    # turns out it's okay ... but sloppy.
    # special case ...
    # for pasting a bunch of BW words along with numbers
    $cmd =~ s{\d}{}xmsg;    
    @new_words = map {
                     lc
                 }
                 split ' ', $cmd;
}

# they found a bonus, donut, or lexicon word
# if they don't yet have a screen name
# it's time to assign them one.
sub check_screen_name {
    if ($screen_name) {
        return;
    }
    my @base = qw/
        Bee
        Drone
        Queen
        Hive
        Worker
        Bumble
        Honey
        Apian
        Buzz
    /;
    my $name = $base[ rand @base ];
    my $i = 1;
    while (exists $screen_name_uuid{"$name$i"}) {
        ++$i;
    }
    $screen_name = "$name$i";
    $uuid_screen_name{$uuid11} = $screen_name;
    $screen_name_uuid{$screen_name} = $uuid11;
    my $url = 'https://logicalpoetry.com/nytbee/help.html#screen_names';
    $message .= "<div class=red>"
             . "You have been assigned a screen name of $screen_name.<br>"
             . "You can change it with the SN command.<br>"
             . "Read all about screen names <a target=_blank href='$url'>here</a>."
             . "</div><p>"
             ;
}

sub pangram_check {
    my ($w, $n, $seven) = @_;
    my $type = $n == 6? 'Donut'
              :$n == 7? 'Lexicon'
              :         'Bonus';
    my $nu_chars = uniq_chars($w);
    my $p = '<span class=purple>Perfect</span>';
    if ($n == $nu_chars) {
        my $perfect = length($w) == $n? $p: '';
        return "This is also a $perfect Pangram $type word! &#128522;<br>";
    }
    elsif ($n == 8 && $nu_chars == 7) {
        my $perfect = length($w) == 7? $p: '';
        return "This is also a $perfect <span style='color: magenta'>Special</span> Pangram $type word! &#128513;<br>";
    }
    return '';
}

my $not_okay_words;
my %is_new_word;
sub check_word {
    my ($w) = @_;
    my $lw = length($w);
    if ($lw < 4) {
        return 'too short';
    }
    if ($lw >= 6) {
        my $s = $w;
        $s =~ s{[$seven]}{}xmsg;
        if (uniq_chars($s) == 1) {
            # one extra letter not in the seven
            if ($osx_usd_words_48{$w} || $first_appeared{$w}) {
                return "bonus";
            }
        }
    }
    if (my (@c) = $w =~ m{$letter_regex}g) {
        #
        # an attempt at a Bonus word failed.
        # 
        # some intense fun is happening here!
        my %seen;
        @c = sort
             map { uc }
             grep {
                !$seen{$_}++;
             }
             @c;
        my $lets;
        my $verb;
        if (@c == 1) {
            $lets = $c[0];
            $verb = 'is not';
        }
        elsif (@c == 2) {
            $lets = "Neither $c[0] nor $c[1]";
            $verb = 'are';
        }
        else {
            my $last = pop @c;
            $lets = "None of " . join(', ', @c) . ", or $last";
            $verb = 'are';
        }
        return "$lets $verb in \U$seven";
    }
    if (index($w, $center) < 0) {
        if ($osx_usd_words_47{$w} || $first_appeared{$w}) {
            # we'll keep the word but not
            # count it for the score of the puzzle
            return 'donut';
        }
        return "does not contain: " . red($Center);
    }
    if (! exists $is_ok_word{$w}) {
        if ($osx_usd_words_47{$w}) {
            # we'll keep the word but not
            # count it for the score of the puzzle
            return 'lexicon';
        }
        return "not in word list";
    }
    return '';
}
WORD:
for my $w (@new_words) {
    next WORD if $w eq '1w';        # hack!
    if (my ($xword) = $w =~ m{\A [-]([a-z]+)}xms) {
        # remove the word from the found list
        if ($is_found{$xword}) {
            for my $w (@found) {
                if (my ($char) = $w =~ m{\A $xword([*+-])}xms) {
                    add_hints($char eq '-'? 1
                             :$char eq '+'? 2
                             :              3);
                }
            }
            @found = grep { !m{\A $xword \b }xms  } @found;
            delete $is_found{$xword};
        }
        else {
            $not_okay_words = "<span class=not_okay>"
                            . uc($xword)
                            . "</span>: not a found word";
        }
        next WORD;
    }
    my $mess = check_word($w);
    if (   $mess eq ''
        || $mess eq 'donut'
        || $mess eq 'lexicon'
        || $mess eq 'bonus'
    ) {
        if ($mess ne '') {
            check_screen_name();
        }
        $is_new_word{$w} = 1;
        if (! $is_found{$w}) {
            $is_found{$w} = 1;
            if ($mess eq 'donut') {
                $not_okay_words .= "<span class=not_okay>"
                                .  def_word(uc($w), $w)
                                .  "</span>: Donut word $thumbs_up -1 hint<br>"
                                .  pangram_check($w, 6);
                add_3word('donut', $date, $w);
                log_it('*donut');
                $w .= '-';
                add_hints(-1);
            }
            elsif ($mess eq 'lexicon') {
                $not_okay_words .= "<span class=not_okay>"
                                .  def_word(uc($w), $w)
                                .  "</span>: Lexicon word $thumbs_up -2 hints<br>"
                                .  pangram_check($w, 7);
                add_3word('lexicon', $date, $w);
                log_it('*lexicon');
                $w .= '+';
                add_hints(-2);
            }
            elsif ($mess eq 'bonus') {
                $not_okay_words .= "<span class=not_okay>"
                                .  def_word(uc($w), $w)
                                .  "</span>: Bonus word $thumbs_up -3 hints<br>"
                                .  pangram_check($w, 8, $seven);
                add_3word('bonus', $date, $w);
                log_it('*bonus');
                $w .= '*';      # * in the found list marks bonus words
                add_hints(-3);
            }
            else {
                if ($is_pangram{$w}) {
                    $not_okay_words .= "Pangram! $thumbs_up<br>";
                }
                # it's a valid word in the allowed list
                # has this word completed a bingo?
                # analyze this before we add it to @found 

                # ignore donut, lexicon, and bonus words
                my @found2 = grep { ! m{[*+-]\z}xms } @found;
                my %first_c;
                WORD:
                for my $fw (@found2) {
                    ++$first_c{substr($fw, 0, 1)};
                }
                if (keys %first_c == 6
                    && ! exists $first_c{substr($w, 0, 1)}
                ) {
                    $not_okay_words .= "YES, you achieved a BINGO! $thumbs_up<br>";
                    if (@found2 == 6) {
                        $not_okay_words .= 'In the FIRST 7 words you found! '
                                        .  ($thumbs_up x 2)
                                        . '<br>';
                        my $in_order = 1;
                        ORDER:
                        for my $i (0 .. 4) {
                            if ($found2[$i] gt $found2[$i+1]) {
                                $in_order = 0;
                                last ORDER;
                            }
                        }
                        if ($in_order && $found2[5] lt $w) {
                            $not_okay_words .= 'Even better, they were found in ALPHABETICAL order! '
                                            .  ($thumbs_up x 3)
                                            . '<br>';
                        }
                        # min/max score??
                        # consider pangram not just length!
                        my %let_score;
                        push @found2, $w;
                        for my $w (@found2) {
                            $let_score{substr($w, 0, 1)}
                                = word_score($w, $is_pangram{$w});
                        }
                        my $max = 1;
                        my $min = 1;
                        for my $w (@ok_words) {
                            my $c = substr($w, 0, 1);
                            my $sc = word_score($w, $is_pangram{$w});
                            if ($sc < $let_score{$c}) {
                                $min = 0;
                            }
                            if ($sc > $let_score{$c}) {
                                $max = 0;
                            }
                        }
                        if ($min) {
                            $not_okay_words .= 'AND with a MINIMUM score! '
                                            .  ($thumbs_up x 4)
                                            .  '<br>';
                        }
                        if ($max) {
                            $not_okay_words .= 'AND with a MAXIMUM score! '
                                            .  ($thumbs_up x 4)
                                            .  '<br>';
                        }
                    }
                }
            }
            push @found, $w;
        }
        else {
            $not_okay_words .= "<span class=not_okay>"
                            .  uc($w)
                            .  "</span>: already found<br>";
        }
    }
    else {
        $not_okay_words .= "<span class=not_okay>"
                        .  uc($w)
                        .  "</span>: $mess<br>";
    }
}

# now that we have added the new words...
# ??? is this right???  why is it called twice?
my $old_rank = $rank;
compute_score_and_rank();
if ($old_rank < $rank && $rank >= 7) {
    log_it("rank$rank");
    $message .= ul( $rank == 7? "Amazing "   .  $thumbs_up
                  :$rank == 8? "Genius "    . ($thumbs_up x 2)
                  :            "Queen Bee " . ($thumbs_up x 3)
                 );
    if ($rank == 8) {
        my @four = grep { ! m{[*+-]\z}xms && length == 4 } @found;
        if (! @four) {
            $message .= ul('And you did it without ANY 4 letter words! '
                           .  $thumbs_up);
            if ($score == $ranks[8]{value}) {
                $message .= ul("On the Nose! <span style='font-size: 24pt'>&#128067</span> $thumbs_up");
            }
        }
    }
}


if (! $prefix && ! $pattern && ! $limit && ! @words_found) {
    # the default when there are no restrictions
    @words_found = sort grep { !m/[*+-]\z/xms } @found;
}

sub dlb_row {
    my ($name, $aref) = @_;
    return '' unless @$aref;
    return Tr(td({ class => 'dlb_name' }, $name),
              td({ class => 'dlb mess' },
                 "@$aref "
               . span({ class => 'gray' }, scalar(@$aref))));
}

sub one_col {
    my ($name, $aref) = @_;
    return '' unless @$aref;
    local $" = "<br>\n";
    return $name
         . "<ul>\n@$aref</ul>\n"
}

sub restrict {
    my ($w_cmd, $aref) = @_;

    if ($w_cmd =~ m{\A (w!?) \s* / \s* (.*) \z}xms) {
        my $not = $1 eq 'w!';
        my $pattern = $2;
        my $regex;
        eval {
            $regex = qr($pattern);
        };
        if ($@) {
            $message = "Illegal pattern: $pattern";
        }
        elsif ($not) {
            return grep { ! m!$regex!xms } @$aref;
        }
        else {
            return grep { m!$regex!xms } @$aref;
        }
    }
    elsif ($w_cmd =~ m{\A w \s* ([<>]) \s* (\d*)\z}xms) {
        $order = $1 eq '>'? 1: -1;
        $limit = $2;
        # by increasing or decreasing length
        # time for a schwarzian transform!
        return grep {
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
               @$aref;
    }
    elsif ($w_cmd =~ m{\A w \s* (\d+) \z}xms) {
        my $len = $1;    # words of a _given_ length
        $prefix = 1;     # set this so that if there are no
                         # words of length $len we will display
                         # nothing instead of the whole list
        if ($len < 4) {
            # makes no sense given all words are >= 4
            # silently ignore this
            return sort @$aref;
        }
        else {
            return grep {
                       length == $len
                   }
                   sort
                   @$aref;
        }
    }
    elsif ($w_cmd =~ m{\A w \s+ ([a-z]+)}xms) {
        $prefix = $1;
        return grep {
                   m{\A $prefix}xms
               }
               sort
               @$aref;
    }
    # can't get here
    return @$aref;
}

#
# now to show the extra words
# we may have a $w_cmd to limit the display
#
my $donut_lexicon_bonus = '';
if ($show_WordList) {
    my @donut;
    my @lexicon;
    my @bonus;
    for my $w (@found) {
        if ($w =~ m{[-]\z}xms) {
            my $x = $w;
            $x =~ s{[-]\z}{}xms;
            push @donut, $x;
        }
        elsif ($w =~ m{[+]\z}xms) {
            my $x = $w;
            $x =~ s{[+]\z}{}xms;
            push @lexicon, $x;
        }
        elsif ($w =~ m{[*]\z}xms) {
            my $x = $w;
            $x =~ s{[*]\z}{}xms;
            push @bonus, $x;
        }
    }
    if (!$order_found) {
        @donut   = sort @donut;
        @lexicon = sort @lexicon;
        @bonus   = sort @bonus;
    }
    if ($w_cmd) {
        @donut   = restrict($w_cmd, \@donut);
        @lexicon = restrict($w_cmd, \@lexicon);
        @bonus   = restrict($w_cmd, \@bonus);
    }
    # highlight new words
    # and perfect donut/bonus pangrams

    # DONUT
    my @new_donut;
    for my $w (@donut) {
        my $uw = ucfirst $w;
        my $nchars = uniq_chars(lc $w);
        my $s;
        if ($nchars == 6) {
            my $color = length $w == 6? 'purple': 'green';
            $s = "<span class=$color>$uw</span>";
        }
        elsif ($is_new_word{lc $w}) {
            $s = "<span class=new_word>$uw</span>";
        }
        else {
            $s = $uw;
        }
        push @new_donut, def_word($s, $w);
    }
    @donut = @new_donut;

    # BONUS
    my @new_bonus;
    for my $w (@bonus) {

        my $uw = ucfirst $w;
        
        # color the non-7 letters red
        $uw =~ s{([^$seven])}{<span class=red1>$1</span>}xmsgi;

        my $nchars = uniq_chars(lc $w);
        my $s;
        if ($nchars == 8) {
            my $color = length $w == 8? 'purple': 'green';
            $s = "<span class=$color>$uw</span>";
        }
        elsif ($is_new_word{lc $w}) {
            $s = "<span class=new_word>$uw</span>";
        }
        else {
            $s = $uw;
        }
        push @new_bonus, def_word($s, $w);
    }
    @bonus = @new_bonus;

    # LEXICON
    @lexicon = map {
                   my $w = $_;
                   my $uw = ucfirst $w;
                   my $s = $is_new_word{$w}?
                               "<span class=new_word>$uw</span>"
                          :    $uw
                          ;
                   def_word($s, $w);
               } 
               @lexicon;
    if ($word_col) {
        $donut_lexicon_bonus  = one_col('Donut:',  \@donut);
        $donut_lexicon_bonus .= one_col('Lexicon', \@lexicon);
        $donut_lexicon_bonus .= one_col('Bonus',   \@bonus);
        if ($donut_lexicon_bonus) {
            $donut_lexicon_bonus = "<br>$donut_lexicon_bonus";
        }
    }
    else {
        $donut_lexicon_bonus  = dlb_row('Donut:',   \@donut)
            unless $bonus_mode;
        $donut_lexicon_bonus .= dlb_row('Lexicon:', \@lexicon)
            unless $bonus_mode;
        $donut_lexicon_bonus .= dlb_row('Bonus:',   \@bonus);
        if ($donut_lexicon_bonus) {
            # convert rows to a table...
            $donut_lexicon_bonus = '<p>' . table($donut_lexicon_bonus);
        }
        if ($bonus_mode && ! $mobile) {
            my @other = grep { !/[$seven]/ } 'a' .. 'z';
            my @bonus = grep { m{[*]\z}xms } @found;
            chop @bonus;    # the *
            my $all = join '', @bonus;
            $all =~ s{[$seven]}{}xmsg;
            my $lets = '<p>';
            for my $o (@other) {
                if (index($all, $o) >= 0) {
                    $lets .= "<span class=green>\u$o</span>";
                }
                else {
                    $lets .= uc $o;
                }
                $lets .= ' ';
            }
            $donut_lexicon_bonus = "$lets$donut_lexicon_bonus";
        }
    }
}
my $bingo_table = '';
if ($show_BingoTable) {
    # we unfortunately determine the bingo status twice
    # once here and again below.
    my %bingo_table;     # { let1 => { min => $min, max => $max, },
                         #   let2 => ... }
    for my $w (@ok_words) {
        my $c = uc substr($w, 0, 1);
        if (! exists $bingo_table{$c}) {
            $bingo_table{$c}= {
                min => 99,
                max => 0,
                minlen => 99,
                maxlen => 0
            };
        }
        my $l = length $w;
        my $sc = word_score($w, $is_pangram{$w});
        my $href = $bingo_table{$c};
        if ($sc < $href->{min}) {
            $href->{min} = $sc;
            $href->{minlen} = $l;
        }
        if ($sc > $href->{max}) {
            $href->{max} = $sc;
            $href->{maxlen} = $l;
        }
    }
    my @rows;
    my $sp = '&nbsp;' x 3;
    for my $c (sort keys %bingo_table) {
        my $min = $bingo_table{$c}{minlen};
        my $max = $bingo_table{$c}{maxlen};
        push @rows, Tr(th({ style => 'text-align: center' }, $c),
                       td($sp
                        . "<span class=pointer"
                        . qq! onclick="issue_cmd('D+$c$min');">!
                        . $min
                        . "</span>"),
                       td($sp
                        . "<span class=pointer"
                        . qq! onclick="issue_cmd('D+$c$max');">!
                        . $max
                        . "</span>"),
                    );
    }
    if (@rows == 7) {
        # if not 7 it's not a bingo puzzle
        $bingo_table = ul(table({ cellpadding => 2}, @rows)) . '<p>';
    }
}
if ($not_okay_words) {
    $message .= ul($not_okay_words);
}

sub color_pg {
    my ($pg) = @_;
    my $class = length($pg) == 7? 'purple': 'green';
    return "<span class=$class>$pg</span>";
}

# two params
# the first is the displayed word (perhaps colored with a span)
# the second is the word itself plain
sub def_word {
    my ($t, $w) = @_;
    qq!<span style='cursor: pointer' onclick="issue_cmd('D $w')">$t</span>!;
}

# time to display the words we have found
# in various orders and various subsets
# which were set above.
# perhaps have a break between words of diff lengths
# in case we had w < or w >.
my $found_words = '';
if ($word_col == 1) {
    my @rows = map {
                   Tr(td({ class => 'lt' }, def_word(ucfirst, $_)))
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
        my $uw = ucfirst $w;
        $words .= def_word(($is_pangram{$w}? color_pg($uw): $uw), $w) . ' ';
    }
    if ($words) {
        push @rows, Tr(td({ class => 'rt', valign => 'top' },
                          $prev_length),
                       td({ class => 'lt', width => 550 },
                          $words)
                      );
    }
    $found_words = table({ cellpadding => 3 }, @rows);
}
elsif ($same_letters) {
    my %groups;
    for my $w (grep { !m{[*+-]\z}xms } @found) {
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
                          join ' ',
                          map { def_word($_, lc) }
                          @{$groups{$cs}}
                       )
                    );
    }
    $found_words = table({ cellpadding => 2 }, @rows);
}
elsif ($first_time) {
    my @rows;
    for my $w (@found) {
        if ($first_appeared{$w} eq $date) {
            my $disp_w = $w;
            if ($is_pangram{$w}) {
                $disp_w = color_pg(ucfirst $w);
            }
            else {
                $disp_w = ucfirst $w;
            }
            push @rows, Tr(td({class => 'lt'}, def_word($disp_w, $w)));
        }
    }
    $found_words = ul(table({ cellpadding => 2 }, @rows));
}
else {
    for my $w (@words_found) {
        my $lw = length($w);
        my $uw = ucfirst $w;
        my $t = $w;
        if ($is_pangram{$w}) {
            $t = color_pg($uw);
        }
        elsif ($is_new_word{$w}) {
            $t = "<span class=new_word>$uw</span>";
        }
        else {
            $t = $uw;
        }
        $t = def_word($t, $w);
        $found_words .= "$t ";
    }
    my $nwords = @words_found;
    if ($nwords) {
        $found_words .= " <span class=gray>$nwords</span>";
    }
}
$found_words = "<div class=found_words>$found_words</div>";
if ($bonus_mode) {
    $found_words = '';
}
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
    ++$sums{$c1}{$l};

    # the summations:
    ++$sums{$c1}{1};
    ++$sums{1}{$l};
    ++$sums{1}{1};

    # and the two letter list
    my $c2 = substr($w, 0, 2);
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

# we unfortunately may have determined the bingo
# status once before - see show_BingoTable above.
my $bingo = keys %first_char == 7? ', Bingo': '';

# now that #we have computed %sums and %two_lets
# perhaps $cmd was not words to add after all...
if ($cmd eq '1' || $cmd eq '51') {
    my $start = $cmd eq '51'? 5: 4;
    # find a random non-zero entry in the hint table
    my @entries;
    for my $l ($start .. $max_len) {
        for my $c (@seven) {
            if ($sums{$c}{$l}) {
                push @entries, "\U$c$l-$sums{$c}{$l}";
            }
        }
    }
    if (@entries) {
        # not Queen Bee yet
        add_hints(1);
        $message .= $entries[ rand @entries ];
    }
    else {
        my $len = $cmd eq '1'? '': ' 5+ letter';
        $message .= "No more$len words.";
    }
    $cmd = '';
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
        $message .= $entries[ rand @entries ];
    }
    else {
        $message .= 'No more words.';
    }
    $cmd = '';
}
elsif ($cmd eq '52') {
    my @words = grep { !$is_found{$_} && length > 4 }
                @ok_words;
    if (@words) {
        add_hints(1);
        my $word = $words[ rand @words ];
        my $l2 = substr($word, 0, 2);
        my $n = grep { m{\A $l2}xms } @words;
        $message .= "\U$l2-$n";
    }
    else {
        $message .= "No more 5+ letter words.";
    }
    $cmd = '';
}

sub td_pangram {
    my ($perfect) = @_;
    td({ class => ($perfect? 'purple': 'green') . ' lt' },
       ('&nbsp'x3)
     . ($perfect? 'perfect ': '')
     . 'pangram')
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
    $message .= "Words: $nwords, Points: $max_score, "
             . "Pangrams: $npangrams$perfect$bingo";
    if ($date =~ m{\A CP}xms) {
        my ($n) = $date =~ m{(\d+)}xms;
        my $created = date($cp_href->{created})->format("%B %e, %Y");
        my $s = <<"EOH";
<span class=pointer style='color: blue' onclick='clues_by(0)'>$cp_href->{name}</span>, $cp_href->{location}<br>
EOH
        $message .= "<br>Community Puzzle #$n - $created<br>Created by $s";
        $message .= cp_message($cp_href, $n);
        $need_show_clue_form = 1;
    }
    else {
        if (! $show_Heading) {
            $message .= "<br>$show_date";
        }
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
elsif ($cmd =~ m{\A (n)?([dlb])w \z}xms) {
    # still need to document it
    # if today's puzzle not before 2:00 a.m. East Coast time
    # add to Cmds pdf, xlsx
    # second column of numbers is the # of people who found it
    # DW, LW, BW - sort by the word
    # NDW, NLW, NBW - sort by the numbers descending then the word
    # pangram (green), perfect pangram (purple)
    # word is red if you found it
    # as usual you can click on each word to get definition and
    # then on the definition to get full wordnik definition.
    #
    my $numeric = $1;
    my $let = uc $2;
    if ($date eq $ymd) {
        $message .= "Sorry, you cannot do \U$cmd\E for today's puzzle.<br>You will need to wait until tomorrow.";
    }
    else {
        my $name = { qw/ D donut L lexicon B bonus / }->{$let};
        open my $in, '<', "$name/$date";
        my %words;
        while (my $w = <$in>) {
            chomp $w;
            ++$words{$w};
        }
        close $in;
        my $nwords = keys %words;
        my $pl = $nwords == 1? '': 's';
        $message .= "$nwords " . ucfirst($name) . " word$pl:<br>\n";
        my @rows;
        my @words = $numeric? (sort {
                                   $words{$b} <=> $words{$a}
                                   ||
                                   $a cmp $b
                               }
                               keys %words)
                   :          (sort keys %words)
                   ;
        for my $w (@words) {
            my $dw = def_word($w, $w);
            my $nuchars = uniq_chars($w);
            my $lw = length $w;
            my $pangram;
            if ($let eq 'B' && $nuchars == 8) {
                $pangram = td_pangram($lw == 8);
            }
            elsif ($let eq 'D' && $nuchars == 6) {
                $pangram = td_pangram($lw == 6);
            }
            elsif ($let eq 'L' && $nuchars == 7) {
                $pangram = td_pangram($lw == 7);
            }
            push @rows, Tr(td({ class => 'lt' },
                              $is_found{$w}? span({ class => 'found_bonus' }, $dw)
                             :               $dw),
                           td({ class => 'rt' }, $words{$w}),
                           $pangram,
                        );
        }
        $message .= table(@rows);
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A cw \s* (\d*) \z}xms) {
    if ($date =~ m{\A cp}xmsi) {
        $message = 'Sorry, CW is only for NYT puzzles.';
    }
    else {
        # I'm confused why \d* and \d+ above don't capture properly
        # test it out
        # order of evaluation of the &&? no.
        my ($max) = $cmd =~ m{(\d+)}xms;
        $max ||= 5;
        # Valid only when the current puzzle is an NYT puzzle.
        # For the day of the current puzzle
        # search the day's log and extra word files to identify
        # the top 5 (10?) locations in Donut, Lexicon, and Bonus words.
        # The C stands for Community or Competitive.
        $message .= `$cgi_dir/nytbee_cw.pl $date $max $seven`;
    }
    $cmd = '';
}
elsif ($cmd eq 'abw') {
    if ($date eq $ymd) {
        $message .= "Sorry, you cannot do ABW for today's puzzle.<br>You will need to wait until tomorrow.";
    }
    else {
        # a separate piece of code for the fancy ABW
        # a bit of duplication
        open my $in, '<', "bonus/$date";
        my %words;
        while (my $w = <$in>) {
            chomp $w;
            ++$words{$w};
        }
        close $in;
        my $nwords = keys %words;
        my $pl = $nwords == 1? '': 's';
        $message .= "$nwords Bonus word$pl:<br>\n";
        # the above could be put into a sub and used below as well
        # param would be donut/lexicon/bonus
        # 3 return values
        my @words_plus = sort {
                             $a->[0] cmp $b->[0]
                             ||
                             $b->[1] <=> $a->[1]
                             ||
                             $a->[2] cmp $b->[2]
                         }
                         map {
                             [
                                extra_let($_, $seven),
                                $words{$_},
                                $_,
                             ]
                         }
                         keys %words;
        my $ncenter = 0;
        my @wlen;
        my @rows;
        my $prev_let = '';
        for my $aref (@words_plus) {
            my $w = $aref->[2];
            if (index($w, $center) >= 0) {
                ++$ncenter;
            }
            ++$wlen[length $w];
            my $count = $aref->[1];
            my $extra = $aref->[0];
            if ($extra ne $prev_let) {
                push @rows, "<tr><td class=lt>" . uc $extra . "</td></tr>";
                $prev_let = $extra;
            }
            my $w_extra = $w;
            $w_extra =~ s{$extra}{<span class=red>$extra</span>}xmsg;
            my $dw = def_word($w_extra, $w);
            my $nuchars = uniq_chars($w);
            my $lw = length $w;
            my $pangram;
            if ($nuchars == 8) {
                $pangram = td_pangram($lw == 8);
            } 
            push @rows, Tr(td(''),
                           td({ class => 'lt' },
                              $is_found{$w}? span({ class => 'found_bonus' }, $dw)
                             :               $dw),
                           td({ class => 'rt' }, $count),
                           $pangram,
                        );
        }
        $message .= table(@rows);
        $message .= "<p>Tallies:<table cellpadding=4 style='margin-left: 5mm'>";
        $message .= "<tr><td>$Center</td><td>$ncenter</td></tr>";
        for my $i (6 .. $#wlen) {
            if ($wlen[$i]) {
                $message .= "<tr><td>$i</td><td>$wlen[$i]</td></tr>";
            }
        }
        $message .= "</table>";
    }
    $cmd = '';
}
elsif ($cmd eq 'boa') {
    $cmd = '';
    my %bwords_with;
    for my $l (grep { !/[$seven]/ } 'a' .. 'z') {
        $bwords_with{$l} = [];
    }
    my @bonus = sort grep { m{[*]\z}xms } @found;
    chop @bonus;    # the *
    for my $bw (@bonus) {
        my $x = $bw;
        $x =~ s{[$seven]}{}xmsg;
        $bw = ucfirst $bw;
        $bw =~ s{([^$seven])}{<span class=red1>$1</span>}xmsgi;
        push @{$bwords_with{substr($x, 0, 1)}}, $bw;
    }
    $message = "<table>\n";
    my $boa_score = 0;
    for my $l (sort keys %bwords_with) {
        my @words = @{$bwords_with{$l}};
        if (@words) {
            ++$boa_score;
        }
        $message .= "<tr><td valign=top style='text-align: center'>\u$l&nbsp;</td>"
                 . "<td class='lt mess'>"
                 . (join ' ', @words)
                 . '</td></tr>';
    }
    $message .= "</table>\n";
    $message .= "<br>$boa_score";
    $message = "<ul>$message</ul>";
}
# an undocumented cheat for Donut words
elsif ($cmd eq 'xdd') {
    my $donut_letters = $seven;
    $donut_letters =~ s{$center}{}xms;
    $cmd = '';
    $message = join '',
               map { "$_<br>\n" }
               `egrep -i '^[$donut_letters]{4,}\$' osx_usd_words-47.txt`;
}
# an undocumented cheat for Bonus words
elsif ($cmd =~ m{\Abb([a-z])\z}xmsi) {
    my $let = $1;
    $cmd = '';
    $message = join '',
               map { "$_<br>\n" }
               `egrep -i '^[$seven$let]{6,}\$' osx_usd_words-48.txt | grep $let`;
}
elsif ($cmd eq 'ow') {
    $cmd = '';
    $message = 'These words were found only by you:<br><br><table>';
    for my $type (qw/ donut lexicon bonus /) {
        $message .= "<tr><td class=rt valign=top>\u$type:</td>";
        my %words;
        if (open my $in, '<', "$type/$date") {
            while (my $w = <$in>) {
                chomp $w;
                ++$words{$w};
            }
            close $in;
        }
        my @words = map {
                        ucfirst
                    }
                    grep { $words{$_} == 1 && $is_found{$_} }
                    sort keys %words;
        my $nwords = @words;
        $message .= "<td class='lt found_words'>@words <span class=gray>$nwords</span></td>";
        $message .= '</tr>';
    }
    $message .= '</table>';
}
elsif ($cmd =~ m{\A m(\d+)? \z}xms) {
    my ($n, $date);
    if ($1) {
        $n = $1;
    }
    else {
        if ($message_for{$uuid}) {
            ($n, $date) = split ' ', $message_for{$uuid};
        }
        else {
            $n = 1;
        }
    }
    if (! -f "messages/$n") {
        $message .= "No such message of the day.";
    }
    else {
        $message .= read_file("messages/$n");
    }
    $cmd = '';
}
elsif ($cmd eq 'id') {
    # show the $uuid so the user can save it
    # for later application with the 'ID ...' command
    $message .= $uuid . " <span id=uuid class=copied></span><script>copy_uuid_to_clipboard('$uuid');</script>";
                       # a clever invisible way to invoke
                       # javascript without a user click...
    $cmd = '';
}
elsif ($cmd =~ m{\A co \s+ (.*)}xms) {
    $message = set_colors($uuid, $1);
    $cmd = '';
}
elsif ($cmd eq 'sn') {
    # they may not have one yet ...
    check_screen_name();
    if (! $message) {
        $message .= $screen_name;
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A sn \s+ (.*) \z}xms) {
    my $new_name = lc $1;
    $new_name =~ s{_([a-z])}{uc $1}xmsge;
    $new_name = ucfirst $new_name;
    if ($new_name eq $screen_name) {
        $message = $screen_name;
    }
    else {
        if (exists $screen_name_uuid{$new_name}) {
            $message .= "Sorry, $new_name is already taken.";
        }
        else {
            # they're actually changing it
            if ($screen_name) {
                # return the old one for reuse
                delete $uuid_screen_name{$uuid11};
                delete $screen_name_uuid{$screen_name};
            }
            $screen_name = $new_name;
            $uuid_screen_name{$uuid11} = $screen_name;
            $screen_name_uuid{$screen_name} = $uuid11;
            $message .= $screen_name;
        }
    }
    $cmd = '';
}
my %colors = get_colors($uuid);

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
        if ($sums{1}{$l} == 0) {
            next LEN;
        }
        push @th, th("$space$l");
    }
    if ($ncols > 1) {
        push @th, th("$space&nbsp;&Sigma;");
    }
    push @rows, Tr(@th);
    CHAR:
    for my $c (@seven) {
        if ($sums{$c}{1} == 0) {
            next CHAR;
        }
        my @cells;
        push @cells, th({ class => 'lt' }, uc $c);
        LEN:
        for my $l (4 .. $max_len) {
            if ($sums{1}{$l} == 0) {
                next LEN;
            }
            push @cells, td($sums{$c}{$l}?
                               "<span class='pointer alink'"
                               . qq! onclick="issue_cmd('D+$c$l');">!
                               . "$sums{$c}{$l}</span>"
                           : $dash
                          );
        }
        if ($sums{$c}{1} != 0 && $ncols > 1) {
            push @cells, th($sums{$c}{1} || 0);
        }
        push @rows, Tr(@cells);
    }
    if ($nrows > 1) {
        @th = th({ class => 'rt' }, '&Sigma;');
        LEN:
        for my $l (4 .. $max_len) {
            if ($sums{1}{$l} == 0) {
                next LEN;
            }
            push @th, th($sums{1}{$l} || $dash);
        }
        if ($ncols > 1) {
            push @th, th($sums{1}{1} || 0);
        }
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
        $two_lets .= qq!<span class='pointer alink' onclick="issue_cmd('D+$two[$i]');">!
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
    $image = "<img src=$log/nytbee/pics/$name.png>";
}
my $rank_image = $show_RankImage?
        "<span class='rank_name rank$rank'>$rank_name</span>$image<br>"
       : $rank_name;

my $disp_nhints = "";
if ($nhints || $rank == 9) {
    $disp_nhints .= " Hints: $nhints";
    $disp_nhints .= ($show_RankImage)? '<br>': ' ';
    if ($rank >= 7) {
        $disp_nhints .= " Ratio: " . sprintf("%.2f", $nhints/$score);
    }
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
    = "<a class=alink onclick='set_focus();' target=_blank href='$log/nytbee/mkpuz.html'>"
    . "Create Puzzle</a>";
my $add_clues_form = '';
if ($date =~ m{\A \d}xms) {
    my $add_edit = index($puzzle_has_clues{$date}, $uuid) >= 0? 'Edit': 'Add';
    $create_add
        .= "&nbsp;&nbsp;<span class=alink onclick='add_clues();'>$add_edit Clues</span>";
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
my $num_msgs = '';
if (my $nm = $num_msgs{$date}) {
    $num_msgs = " <span class=red>$nm</span>";
}

my $heading = $show_Heading? <<"EOH": '';
<div class=float-child1>
    <a target=_blank class=alink onclick="set_focus();" href='https://www.nytimes.com/subscription'>NY Times</a> Spelling Bee<br>$show_date$clues_are_present
</div>
<div class=float-child2>
     <img width=53 src=$log/nytbee/pics/bee-logo.png onclick="navigator.clipboard.writeText('$cgi/nytbee.pl/$date');show_copied('logo');set_focus();" class=link><br><span class=copied id=logo></span>
</div>
<div class=float-child3>
    <div style="text-align: center"><span class=help><a class=alink target=nytbee_help onclick="set_focus();" href='$log/nytbee/help.html#toc'>Help</a></span>&nbsp;&nbsp;<span class=help><a target=_blank class=alink href='$log/nytbee/cmd_list.pdf'>Cmds</a><br><span class=create_add'>$create_add</span><br><a class='alink' onclick="issue_cmd('F');">Forum</a> $num_msgs</div>
</div>
<br><br>
EOH

my $letters = '';
if ($hive == 3) {
    $letters = <<"EOH";
<pre>
     $six[0]   $six[1]
   $six[2]   <span class=red2>\U$center\E</span>   $six[3]
     $six[4]   $six[5]
</pre>
EOH
}
elsif ($hive == 1) {        # bee hive honeycomb
    $letters = svg_hex($mobile);
    $letters =~ s{LET0}{$Center}xmsg;
    for my $i (1 .. 6) {
        $letters =~ s{LET$i}{$six[$i-1]}xmsg;
    }
    $letters =~ s{CENTER_HEX}{$colors{center_hex}}xmsg;
    $letters =~ s{CENTER_TEXT}{$colors{center_text}}xmsg;
    $letters =~ s{DONUT_HEX}{$colors{donut_hex}}xmsg;
    $letters =~ s{DONUT_TEXT}{$colors{donut_text}}xmsg;
    if ($mobile) {
        # enter, wordlets, delete, define
        # all positioned absolutely as well
sub click_td {
    my ($l, $color) = @_;
    $color = $color? 'green': $colors{letter};
    # tried putting text-align: center in bonus_let style
    # didn't work 
    # this is messy.  better to use a class instead of a style...
    # it works, yes, but clean it up.
    my $disp_l = $l eq 'I'? '&nbsp;I&nbsp;': $l;
    return td({ style => "text-align: center;"},
               "<span class='bonus_let cursor_black' style='color: $color'"
             . qq! onclick="add_redlet('$l')">$disp_l</span>!);
}
        if ($bonus_mode) {
            my @blets = grep { !/[$seven]/ } 'a' .. 'z';
            # determine which additional letters have
            # been used in a Bonus word
            my %used_in_bonus;
            for my $b (grep { m{[*]\z}xms } @found) {
                $b =~ s{[$seven]}{}xmsg;
                $used_in_bonus{substr($b, 0, 1)}++;
            }
            my $row1 = Tr(map { click_td(uc, $used_in_bonus{$_}) }
                          @blets[0 .. 9]);
            my $row2 = Tr(map { click_td(uc, $used_in_bonus{$_}) }
                          @blets[10 .. 18]);
            my $bonus_table = <<"EOH";
<table cellpadding=0 cellspacing=10>
$row1
$row2
</table>
EOH
            $letters .= <<"EOH";
<span class=lets id=lets></span>
<span class='enter alink' onclick="sub_lets();">Enter</span>
<span class='define alink' onclick="del_let();">Delete</span>
<span class='standings alink' onclick="issue_cmd('CW');">Standings</span>
<span class='own alink' onclick="issue_cmd('OW');">Own</span>
<span class='bonus2 alink' onclick="issue_cmd('BN');">Bonus</span>
</span>
<span class=bonus_lets>$bonus_table</span>
EOH
        }
        else {
            $letters .= <<"EOH";
<span class='enter cursor_black alink' onclick="sub_lets();">Enter</span>
<span class='define cursor_black alink' onclick="issue_cmd('D+R');">Define</span>
<span class='bonus cursor_black alink' onclick="issue_cmd('BN');">Bonus</span>
<span class=lets id=lets></span>
<span class='delete cursor_black alink' onclick="del_let();">Delete</span>
<span class='helplink cursor_black'>
<a class='cursor_black alink' target=_blank href='$log/nytbee/help.html#toc'">Help</a></span>
<span class='forum cursor_black alink' onclick="issue_cmd('F');">Forum $num_msgs</span>
EOH
        }
    }
}
elsif ($hive == 2) {    # hex letters
    if ($mobile) {
        $letters = "<div class=h3lets id=lets>&nbsp;</div>";
        $letters .= "<table width=100%><tr>\n";
        for my $c (@seven_let) {
            my $class = $c eq uc $center? 'red2 biglet': 'biglet';
            $letters .= "<td class='$class' width='14.28%'>"
                     .  qq!<span onclick="add_let('$c')">$c</span>!
                     .  "</td>";
        }
        $letters .= "</tr></table>\n";
        $letters .= "<table style='width: 100%; margin-bottom: 10mm'><tr>"
                 .  "<td class=h3cmd onclick='del_let()'>Delete</td>"
                 .  "<td class='h3cmd'><a style='color: black' target=_blank href='$log/nytbee/help.html#toc'>Help</a></td>"
                 .  qq!<td class=h3cmd onclick="issue_cmd('DR');">Define</td>!
                 .  "<td class=h3cmd onclick='sub_lets()'>Enter</td>"
                 .  "</tr></table>"
                 ;
    }
    else {
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
}

my $hint_table_list = '';
if ($ht_chosen && $sums{1}{1} != 0) {
    $hint_table_list .= <<"EOH";
<div class=float-child4>
    <div id=hint_table class=hint_table>
    $hint_table
    </div>
</div>
EOH
}
if ($tl_chosen && $sums{1}{1} != 0) {
    $hint_table_list .= <<"EOH";
<div class=float-child5>
    <div id=two_lets class=two_lets>
    $two_lets
    </div>
</div>
EOH
}
if ($bonus_mode) {
    $hint_table_list = '';
}

sub graphical_status {
    my $ind1 = 2;
    my $ind2 = 28;
    my $between_lines = 22;
    my $between_dots = 11;
    my $dotr1 = 2;
    my $dotr2 = 5;
    my $html = "";
    my @color = qw/
        8E008E
        400098
        00C0C0
        008E00
        FFFF00
        FF8E00
        FF0000
        FF6599
        CD66FF
    /;
    my $rainbow_width = 9;
    my $mark_height = 7;
    my $width = $ind2 + $between_dots*($nwords-1) + 26;
        # 26 extra to accomodate a plus sign + at the end of the hints
    my $height = (($bingo? 1: 0) + ($nhints? 1: 0) + 3) * 23;
               #    b                 h             pws
    $html = <<"EOH";
    <style>
    .glets, .bold_glets {
        font-size: 18pt;
        font-family: Courier New;
    }
    .bold_glets {
        font-weight: bold;
        font-size: 20pt;
    }
    </style>
    <svg width=$width height=$height>
EOH
    my $y = $between_lines;
    if ($bingo) {
        my %first_found;
        for my $w (grep { !m{[*+-]\z}xms } @found) {
            ++$first_found{uc substr($w, 0, 1)};
        }
        $html .= "<text x=$ind1 y=$y class=glets>b</text>\n";
        my $x = $ind2;
        for my $c (map { uc } @seven) {
            my ($color, $class) = ('black', 'glets');
            if ($first_found{$c}) {
                ($color, $class) = ('#8E008E', 'bold_glets');
            }
            $html .= "<text x=$x y=$y class=$class fill=$color>$c</text>\n";
            $x += 20;
        }
        $y += $between_lines;
    }

    $html .= "<text x=$ind1 y=$y class=glets>p</text>\n";
    my $x = $ind2;
    $y -= 4;
    my $npangrams_found = grep { $is_found{$_} } @pangrams;
    for my $i (1 .. $npangrams_found) {
        $html .= "<circle cx=$x cy=$y r=$dotr2 fill=#00C0C0></circle>\n";
        $x += $between_dots;
    }
    for my $i ($npangrams_found+1 .. $npangrams) {
        $html .= "<circle cx=$x cy=$y r=$dotr1 fill=black></circle>\n";
        $x += $between_dots;
    }
    $y += 4;
    $y += $between_lines;

    my $w_ind = $ind1-2;
    $html .= "<text x=$w_ind y=$y class=glets>w</text>\n";
    $x = $ind2;
    $y -= 4;
    my $nfound = grep { !m{[*+-]\z}xms } @found;
    for my $i (1 .. $nfound) {
        $html .= "<circle cx=$x cy=$y r=$dotr2 fill=green></circle>\n";
        $x += $between_dots;
    }
    for my $i ($nfound+1 .. $nwords) {
        $html .= "<circle cx=$x cy=$y r=$dotr1 fill=black></circle>\n";
        $x += $between_dots;
    }
    $y += 4;
    $y += $between_lines;

    $html .= "<text x=$ind1 y=$y class=glets>s</text>\n";

    # a black line from 0 to max_score
    $y -=5; # centered on the S
    my $max_x = $ind2 + ($nwords-1)*$between_dots;
    my $x1 = $ind2;
    $html .= "<line x1=$x1 y1=$y x2=$max_x y2=$y stroke=black stroke-width=1></line>\n";

    # colored ranks between the percentages
    # but only up to the score %
    my @pct = (0, 2, 5, 9, 15, 25, 40, 50, 70, 100);
    my $score_pct = ($score/$max_score)*100;
    PCT:
    for my $i (0 .. $#pct-1) {
        my $x1 = $ind2 + ($pct[$i]/100)*($max_x - $ind2);
        if ($score_pct < $pct[$i+1]) {
            my $x2 = $ind2 + ($score_pct/100)*($max_x - $ind2);
            $html .= "<line x1=$x1 y1=$y x2=$x2 y2=$y stroke='#$color[$i]' stroke-width=$rainbow_width></line>\n";
            last PCT;
        }
        my $x2 = $ind2 + ($pct[$i+1]/100)*($max_x - $ind2);
        $html .= "<line x1=$x1 y1=$y x2=$x2 y2=$y stroke='#$color[$i]' stroke-width=$rainbow_width></line>\n";
    }

    # vertical marks between ranks
    my $y1 = $y-$mark_height;
    my $y2 = $y+$mark_height;
    for my $pct (@pct) {
        my $x1 = $ind2 + ($pct/100)*($max_x - $ind2);
        my $x2 = $x1;
        $html .= "<line x1=$x1 y1=$y1 x2=$x2 y2=$y2 stroke=black stroke-width=1></line>\n";
    }
    $y += 4;
    $y += $between_lines;

    # hints
    if ($nhints) {
        $html .= "<text x=$ind1 y=$y class=glets>h</text>\n";
        $x = $ind2;
        $y -= 5;
        HINT:
        for my $i (1 .. abs($nhints)) {
            if ($i > $nwords) {
                $html .= "<text x=$x y=$y class=glets>+</text>\n";
                last HINT;
            }
            else {
                my $color = $nhints > 0? 'black': 'red';
                $html .= "<circle cx=$x cy=$y r=$dotr1 fill=$color></circle>\n";
            }
            $x += $between_dots;
        }
    }

    $html .= "</svg>\n";
    return $html;
}

my $status = $show_GraphicStatus? graphical_status()
            :                     "Score: $score $rank_image $disp_nhints";
if ($bonus_mode) {
    $status = '';
}
my $css = $mobile? 'mobile_': '';
my $new_words_size = $mobile? 30: 40;
my $enter_top  = 90 + ($show_Heading? 79: 0);
my $define_top  = 90 + ($show_Heading? 79: 0);
my $bonus_top  = 40 + ($show_Heading? 79: 0);
my $lets_top   = 135 + ($show_Heading? 79: 0);
my $bonus_lets_top   = 185 + ($show_Heading? 79: 0);
my $delete_top = 190 + ($show_Heading? 79: 0);
my $help_top = 190 + ($show_Heading? 79: 0);
my $forum_html = '';
if ($forum_mode) {
    $forum_html = `$cgi_dir/show_forum.pl $date "$screen_name" $forum_post_to_edit`;
    $bingo_table =
    $found_words =
    $donut_lexicon_bonus =
    $status =
    $hint_table_list = '';
}
print <<"EOH";
<html>
<head>
<meta charset='UTF-8'>
<title>Spelling Bee - $show_date</title>
<style>
body {
    background: $colors{background};
    color: $colors{letter};
}
.letter {
    color: $colors{letter};
}
.alink {
    color: $colors{alink};
    cursor: pointer;
}
.enter {
    position: absolute;
    left: 320;
    top: $enter_top;
}
.define {
    position: absolute;
    left: 420;
    top: $define_top;
}
.own {
    position: absolute;
    left: 420;
    top: $bonus_top;
}
.bonus {
    position: absolute;
    left: 520;
    top: $define_top;
}
.forum {
    position: absolute;
    left: 520;
    top: $help_top;
}
.standings {
    position: absolute;
    left: 520;
    top: $define_top;
}
.bonus2 {
    position: absolute;
    left: 520;
    top: $bonus_top;
}
.lets {
    position: absolute;
    left: 320;
    top: $lets_top;
    font-size: 28pt;
    color: green;
}
.bonus_lets {
    position: absolute;
    left: 310;
    top: $bonus_lets_top;
}
.bonus_let {
    font-size: 22pt;
    font-weight: bold;
    cursor: black;
}
.bonus_delete {
    position: absolute;
    left: 320;
    top: $delete_top;
}
.delete {
    position: absolute;
    left: 320;
    top: $delete_top;
}
.helplink {
    position: absolute;
    left: 420;
    top: $help_top;
}
</style>
<link rel='stylesheet' type='text/css' href='$log/nytbee/css/cgi_${css}style.css'/>
<script src="$log/nytbee/js/nytbee5.js"></script>
</head>
<body onload='init(); $focus'>
$heading
<form id=main name=form method=POST action='$cgi/nytbee.pl'>
<input type=hidden name=date value='$date'>
<input type=hidden name=has_message value=$has_message>
<input type=hidden name=six value='@six'>
<input type=hidden name=seven_let value='@seven_let'>
<input type=hidden name=hive value=$hive>
<input type=hidden name=show_Heading value=$show_Heading>
<input type=hidden name=show_WordList value=$show_WordList>
<input type=hidden name=show_BingoTable value=$show_BingoTable>
<input type=hidden name=bonus_mode value=$bonus_mode>
<input type=hidden name=forum_mode value=$forum_mode>
<input type=hidden name=show_RankImage value=$show_RankImage>
<input type=hidden name=show_GraphicStatus value=$show_GraphicStatus>
$letters
<div style="width: 640px">$message</div>
<input type=hidden name=hidden_new_words id=hidden_new_words>
<input class=new_words
       type=text
       size=$new_words_size
       id=new_words
       name=new_words
       autocomplete=off
>
<p>
$bingo_table
$found_words
$donut_lexicon_bonus
<p>
$status$hint_table_list
$forum_html
</form>
</body>
$show_clue_form$add_clues_form
<script src="$log/nytbee/js/fastclick.js"></script>
<script>
if ('addEventListener' in document) {
    document.addEventListener('DOMContentLoaded', function() {
        FastClick.attach(document.body);
    }, false);
}
</script>
</html>
EOH
