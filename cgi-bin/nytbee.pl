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
    uniq_words
    cgi_header
    my_today
    red
    trim
    slash_date
    shuffle
    word_score
    JON
    $log
    $cgi
    $cgi_dir
    $thumbs_up
    get_html
    mark_up
    jumble
/;
use BeeHTML qw/
    table
    Tr
    td
    th
    div
    span
    ul
    bold
/;
use BeeColor qw/
    set_colors
    get_colors
    arr_get_colors
    save_colors
    color_schemes
    del_scheme
/;
use BeeDBM qw/
    %end_time_for
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
    %settings_for
    %full_uuid
    %added_words
/;
use SvgHex qw/
    svg_hex
/;
use JSON qw/
    decode_json
/;
use Date::Simple qw/
    today
    date
/;
use DB_File;
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
use BeeExt qw/
    $ext_mobile_css
    $ext_desktop_css
    $ext_logo_base64
    $ext_fastclick
    $ext_script
/;

my $message = '';
my $ymd = ymd();
my $ext_sig = '!*+-';   # extra word sigils
                        # ! stash * bonus + lexicon - donut
my $not_okay_words;
my $n_minus = 0;

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
my $q = CGI->new();
if (-f "sys_maint.txt") {
    print $q->header(), read_file('sys_maint.txt');
    exit;
}
my $hive = $q->param('hive') || 1;
my $uuid = cgi_header($q);
my %colors = get_colors($uuid);
my $uuid11 = substr($uuid, 0, 11);
# unfortunate ... - premature optimization :(
if (! exists $full_uuid{$uuid11}) {
    $full_uuid{$uuid11} = $uuid;
}
my %params = $q->Vars();

sub now_secs {
    my ($second, $minute, $hour) = (localtime)[0 .. 2];
    --$hour;    # west coast time
    return 60*60*$hour + 60*$minute + $second;
}

my ($status_display, $only_clues, $pw_feedback, $no_define);
sub redo_settings {
    my ($how) = @_;
    if ($how eq 'in') {
        # initialize
        if (exists $settings_for{$uuid}) {
            ($status_display, $only_clues, $pw_feedback, $no_define)
                = split ' ', $settings_for{$uuid};
            return;
        }
        else {
            ($status_display, $only_clues, $pw_feedback, $no_define)
                = (0, 0, 0, 0);
        }
    }
    elsif ($how eq 'st') {
        $status_display = ($status_display + 1) % 4;
    }
    elsif ($how eq 'oc') {
        $only_clues = $only_clues? 0: 1;
    }
    elsif ($how eq 'nd') {
        $no_define = $no_define? 0: 1;
    }
    elsif ($how eq 'pf') {
        $pw_feedback = ($pw_feedback + 1) % 3;
    }
    # reset it in the .dbm file
    $settings_for{$uuid} = "$status_display $only_clues $pw_feedback $no_define";
}
redo_settings('in');

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
if ($params{new_words} =~ m{\A \s* (id|~pb) \s+}xmsi) {
    # we took care of this case in cgi_header
    $params{new_words} = '';
}
# search for 'id' below

my $screen_name = '';
if (exists $uuid_screen_name{$uuid11}) {
    $screen_name = $uuid_screen_name{$uuid11};
}

my $mobile = $params{mobile_Device}
             || $ENV{HTTP_USER_AGENT} =~ m{iPhone|Android}xms;
my $focus = $mobile? '': 'set_focus();';
my $position_attr = $mobile? 'static': 'absolute';

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
my $cps = $cur_puzzles_store{$uuid};
if ($cps) {
    %cur_puzzles = %{ eval $cps };    # the key point #1 (see below for #2)
}
else {
    # otherwise this is a brand new user...
}

sub log_it {
    my ($msg) = @_;
    append_file "beelog/$ymd", substr($uuid, 0, 11) . " = $msg\n";
}
# is the word already in the file?
sub own_word {
    my ($type, $date, $w) = @_;
    open my $in, '<', "$type/$date";
    while (my $word = <$in>) {
        chomp $word;
        if ($word eq $w) {
            return '';
        }
    }
    close $in;
    return "Own ";
}
sub add_4word {
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
            (split ' ', $cur_puzzles{$_})[2, 7]     # all_pangrams?, rank
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
    my $desc = mark_up($cp_href->{description});
    if ($desc) {
        $mess = "<div class=description>$desc</div>";
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

my $mobile_Device   = exists $params{mobile_Device}?
                             $params{mobile_Device}: $mobile;
my $show_Heading    = exists $params{show_Heading}?
                             $params{show_Heading}: !$mobile;
my $show_Links      = exists $params{show_Links}?
                             $params{show_Links}: !$mobile;
my $show_WordList   = exists $params{show_WordList}?
                             $params{show_WordList}: 1;
my $which_wl        = exists $params{which_wl}?
                             $params{which_wl}: 'pdlbs';
my $show_BingoTable = exists $params{show_BingoTable}?
                             $params{show_BingoTable}: 0;
my $bonus_mode      = exists $params{bonus_mode}?
                             $params{bonus_mode}: 0;
my $donut_mode      = exists $params{donut_mode}?
                             $params{donut_mode}: 0;
my $forum_mode      = exists $params{forum_mode}?
                             $params{forum_mode}: 0;
my $show_RankImage  = exists $params{show_RankImage}?
                             $params{show_RankImage}: 1;

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
    if ($date =~ m{cp}xmsi) {
        $date = ($today-1)->as_d8();
    }
    else {
        my $new_date = (date($date)-1)->as_d8();
        if ($new_date < $first->as_d8()) {
            $message = 'The first NYT Spelling Bee Puzzle was on May 9, 2018.';
        }
        else {
            $date = $new_date;
        }
    }
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
       && $cmd ne '3'
       && $cmd ne '52'
       && $cmd ne '51'
       && $cmd ne '53'
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
    $show_date = qq!<span class=alink onclick="issue_cmd('I');">$show_date</span>!;
    $show_date = "<a target=_blank class=alink onclick='set_focus();' href='https://www.nytimes.com/subscription'>NYT</a> $show_date";
    my $puzzle = $puzzle{$date};
    if (! $puzzle) {
        no_puzzle $show_date;
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
    $show_date = qq!<span class=alink onclick="issue_cmd('I');">$show_date</span>!;
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
        %nyt_clues_for     = %{ eval read_file "clues/$date" };
        %nyt_cluer_name_of = %{ eval read_file "cluers/$date" };
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
    $n_overall_hints,
    $ht_chosen,
    $tl_chosen,
    $t3_chosen,
    $jt_chosen,
    $score_at_first_hint,
    $score,
    $rank_name,
    $rank);
my %is_new_word;

sub in_stash {
    my ($w) = @_;
    return grep { $_ eq "$w!" } @found;
}

my $n_hints_added = 0;
sub add_hints {
    my ($n) = @_;
    $n_hints_added += $n;
        # could be more than once - like DCO to define
        # multiple words beginning with CO
    if ($n > 0 && $score_at_first_hint < 0) {
        $score_at_first_hint = $score;
    }
    $nhints += $n;
    $n_overall_hints += $n;
}

if (exists $cur_puzzles{$date}) {
    my ($ap, $rank);    # all pangrams is not needed here...
                        # rank is recomputed
    ($nhints, $n_overall_hints, $ap,
     $ht_chosen, $tl_chosen, $t3_chosen, $jt_chosen,
     $rank, $score_at_first_hint,
     @found)
        = split ' ', $cur_puzzles{$date};
}
else {
    $nhints    = 0;
    $n_overall_hints = 0;
    $ht_chosen = 0;
    $tl_chosen = 0;
    $t3_chosen = 0;
    $jt_chosen = 0;
    $rank      = 0;
    $score_at_first_hint = -1;  # -1 since we may ask for a hint
                                # at the very beginning!
    @found     = ();
}

# shall we show a message about doing ID and SN?
if (assigned_sn($screen_name)
    && $date eq $today->as_d8()
    && @found == 0
    && my_puzzles() > 3
) {
    $message = <<"EOM";
Greetings,
<p>
$screen_name is the screen name you were randomly assigned.
Please choose your own private identity string and public screen name.
It is all explained in the help file <a target=_blank href='https://ultrabee.org/help.html#screen_names'>here</a>.
<p>
Thank you
<p>
EOM
}

if ($cmd eq 'q' || $cmd eq '?') {
    # define the last word
    my $word = $found[-1];
    if (! $word) {
        $message = "No words have been found.";
        $cmd = '';        
    }
    else {
        $word =~ s{[$ext_sig]\z}{}xms;
        $cmd = "d $word";
    }
}
my %is_found = map {
                   my $x = $_;
                   $x =~ s{[$ext_sig]\z}{}xms;
                   $x => 1;
               }
               @found;
sub own_counts {
    my @rv;
    for my $type (qw/ donut bonus lexicon /) {
        my %words;
        if (open my $in, '<', "$type/$date") {
            while (my $w = <$in>) {
                chomp $w;
                ++$words{$w};
            }
            close $in;
        }
        push @rv, scalar
                  grep { $words{$_} == 1 && $is_found{$_} }
                  sort keys %words;
    }
    return @rv;
}

sub compute_score_and_rank {
    $score = 0;
    WORD:
    for my $w (@found) {
        next WORD if $w =~ m{[$ext_sig] \z}xms;   # extra
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
# and not dp, dx1, dx, dxy, or d-xyz
#
# if fullword we don't tally hints and we don't mask the word
sub define {
    my ($word, $fullword) = @_;

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
    if ($fullword || ! $only_clues) {
        if (! exists $definition_of{$word}) {
            my $rv = in_wordnik($word);
                # the above may set $definition_of{$word}
        }
        if (exists $definition_of{$word}) {
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
    }
    return "<span class=letter>" . ucfirst($def) . "</span>";
}

sub do_define {
    my ($term) = @_;

    my $nhints = $only_clues? 2: 3;

    load_nyt_clues;
    my $msg = '';
    my $line = "&mdash;" x 4;
    if ($term eq 'p') {
        my $npangrams =  0;
        for my $p (grep { !$is_found{$_} } @pangrams) {
            ++$npangrams;
            my $def = define($p, 0);
            add_hints($nhints) unless $def =~ $no_def;
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
        #
        # if there are no 4 letter words in the @found array
        # then this will be like a D5.
        #
        my $n4 = 0;
        WORD:
        for my $w (@found) {
            if (length $w == 4) {
                $n4 = 1;
                last WORD;
            }
        }
        my @words = grep { !$is_found{$_} && ($n4 || length >= 5)  }
                    @ok_words;
        if (! @words) {
            # no more 5+ letter words
            # there may be 4 letter words
            @words = grep { !$is_found{$_} }
                        @ok_words;
        }
        if (! @words) {
            $msg .= 'No more words.';
        }
        else {
            $msg .= define($words[ rand @words ], 0);
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
            $msg .= define($words[ rand @words ], 0);
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
                my $def = define($w, 0);
                add_hints($nhints) unless $def =~ $no_def;
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
                my $def = define($w, 0);
                add_hints($nhints) unless $def =~ $no_def;
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
    elsif ($term =~ m{\A [-]([a-z][a-z][a-z]) \z}xms) {
        my $lets = $1;
        if ($lets =~ $letter_regex) {
            $msg .= ul(red(uc $cmd) . ": \U$1\E is not in \U$seven");
        }
        else {
            $msg .= '';
            for my $w (get_words($lets)) {
                my $def = define($w, 0);
                add_hints($nhints) unless $def =~ $no_def;
                if ($def) {
                    $msg .= ul($def) . '--';
                }
            }
            $msg =~ s{--\z}{}xms;
            $msg =~ s{--}{$line<br>}xmsg;
            if ($msg) {
                $msg = "\U$lets\E:<br>$msg";
            }
        }
        $cmd = '';
    }
    elsif ($term =~ m{\A [~]([a-z]+)=([a-z]+) \z}xms) {
        $msg .= uc($2) . ':';
        my $w = reverse $1;
        my $def = define($w, 0);
        add_hints($nhints) unless $def =~ $no_def;
        if ($def) {
            $msg .= ul($def);
        }
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

my $points_added = 0;

if ($cmd eq 'pg') {
    my $n = $ranks[8]{value} - $score;
    if ($n <= 0) {
        $n = -$n;
        my $pl = $n == 1? '': 's';
        $message = $n == 0? "You are at Genius ON THE NOSE! $thumbs_up"
                  :         "You have $n point$pl over Genius.";
        my $nextra = grep { m{[$ext_sig]\z}xms } @found;
        my $to_qb = @ok_words - @found + $nextra;
        my $pl2 = $to_qb == 1? '': 's';
        $message .= "<br>$to_qb more word$pl2 to Queen Bee.";
    }
    else {
        my $pl = $n == 1? '': 's';
        $message = "$n point$pl to Genius";
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A co \s+ (.*)}xmsa    # specific color setting
       || $cmd =~ m{\A co([a-z]) \z}xms # a preset
) {
    $message = set_colors($uuid, $1);
    %colors = get_colors($uuid);
    $cmd = '';
}
elsif ($cmd =~ m{\A sco \s+ ([a-z]) \s+ hello! \z}xms) {
    # official saving of a PreSet
    my $let = $1;
    $message = save_colors($uuid, "preset $let");
    $cmd = '';
}
elsif ($cmd eq 'lco') {
    $message = color_schemes($uuid);
    $cmd = '';
}
elsif ($cmd =~ m{\A xco \s+ (\w+) \z}xms) {
    $message = del_scheme($uuid, $1);
    $cmd = '';
}
elsif ($cmd eq 'co') {
    my @c = arr_get_colors($uuid);
    $message = <<"EOH";
<style>
/* align td left just for the co table */
.co td {
    text-align: left;
}
</style>
<table cellpadding=3 class=co>
<tr><td>1</td><td>Center background</td><td>$c[0]</td></tr>
<tr><td>2</td><td>Center text</td></td><td>$c[1]</td></tr>
<tr><td>3</td><td>Donut background</td></td><td>$c[2]</td></tr>
<tr><td>4</td><td>Donut text</td></td><td>$c[3]</td></tr>
<tr><td>5</td><td>Page background</td></td><td>$c[4]</td></tr>
<tr><td>6</td><td>Page text</td></td><td>$c[5]</td></tr>
<tr><td>7</td><td>Links</td></td><td>$c[6]</td></tr>
<tr><td>8</td><td>Input background</td></td><td>$c[7]</td></tr>
<tr><td>9</td><td>Input text</td></td><td>$c[8]</td></tr>
</table>
EOH
    $cmd = '';
}
elsif ($cmd =~ m{\A sco \s+ (\w+) \z}xms) {
    # saving to personal color scheme by name
    my $name = $1;
    $message = save_colors($uuid, $name);
    $cmd = '';
}
elsif ($cmd eq 'sa') {
    my @stash = map { /(\w+)!\z/? $1: () } @found;
    for my $w (@stash) {
        delete $is_found{$w};
    }
    $cmd = "@stash";
}
elsif ($cmd =~ m{\A sa \s* 5 \z}xms) {
    my @stash = map { /(\w{5,})!\z/? $1: () }  @found;
    for my $w (@stash) {
        delete $is_found{$w};
    }
    $cmd = "@stash";
}
# sa with a regexp
elsif ($cmd =~ m{\A sa \s+ (.+) \z}xmsi) {
    # confusing and tricky, seems to work
    my $s = $1;
    $s =~ s{\$}{\\b}xms;
    my @stash = map { m/(.*)!\z/xms; }
                grep { m/$s.*!/xms; }
                @found;
    @found = grep { !m/$s.*!\z/xms; } @found;
    for my $w (@stash) {
        delete $is_found{$w};
    }
    $cmd = "@stash";
}
elsif ($cmd eq 'ht') {
    if (! $ht_chosen) {
        $ht_chosen = 1;
        add_hints(10);
    }
    $cmd = '';
}
elsif ($cmd eq 'jt') {
    if (! $jt_chosen) {
        $jt_chosen = 1;
        add_hints(20);
    }
    $cmd = '';
}
elsif ($cmd eq 'jr') {
    my @un_found = grep { !$is_found{$_} } @ok_words;
    $message = uc jumble $un_found[ rand @un_found ];
    add_hints(3);
    $cmd = '';
}
elsif ($cmd eq 'tl') {
    if (! $tl_chosen) {
        $tl_chosen = 1;
        add_hints(5);
    }
    $cmd = '';
}
elsif ($cmd eq 't3') {
    if (! $t3_chosen) {
        $t3_chosen = 1;
        add_hints(15);
    }
    $cmd = '';
}
elsif ($cmd eq 'he') {
    $show_Heading = $show_Heading? 0: 1;
    $cmd = '';
}
elsif ($cmd eq 'ln') {
    $show_Links = $show_Links? 0: 1;
    $cmd = '';
}
elsif ($cmd eq 'mo') {
    $mobile_Device = $mobile_Device? 0: 1;
    $show_Heading = $mobile_Device? 0: 1;
    $mobile = $mobile_Device;
    $focus = $mobile? '': 'set_focus();';
    $position_attr = $mobile? 'static': 'absolute';
    $cmd = '';
}
elsif ($cmd eq 'wl') {
    $show_WordList = $show_WordList? 0: 1;
    if (!$show_WordList) {
        $message .= "Hiding all found words.<br>WL will show them again.";
    }
    $which_wl = 'pdlbs';
    $cmd = '';
}
elsif ($cmd =~ m{\A wl \s* ([pdlbsa]+)}xms) {
    $show_WordList = 1;
    $which_wl = $1;
    if ($which_wl =~ /a/) {
        $which_wl = 'pdlbs';
        $message .= "Showing all words.";
    }
    else {
        my @x;
        my %name_for = qw/
            p Puzzle
            d Donut
            l Lexicon
            b Bonus
            s Stash
        /;
        for my $l (split //, $which_wl) {
            push @x, $name_for{$l};
        }
        @x = uniq_words @x;
        my $x;
        if (@x == 1) {
            $x = $x[0];
        }
        elsif (@x == 2) {
            $x = join ' and ', @x;
        }
        else {
            $x = join ', ', @x;
            $x =~ s{,([^,]*)\z}{, and$1}xms;
        }
        $message .= "Showing only $x words.<br>WLA will show All.";
    }
    $cmd = '';
}
elsif ($cmd eq 'bt') {
    $show_BingoTable = $show_BingoTable? 0: 1;
    $cmd = '';
}
elsif ($cmd eq 'oc') {
    redo_settings('oc');
    $message = $only_clues? 'Only clues'
              :             'Both clues and definitions';
    $cmd = '';
}
elsif ($cmd eq 'nd') {
    redo_settings('nd');
    $message = $no_define? 'NO Define Link'
              :            'Define Link';
    $cmd = '';
}
elsif ($cmd eq 'pf') {
    redo_settings('pf');
    $message = $pw_feedback == 0? "Inline"
              :$pw_feedback == 1? "Flash"
              :                   "Silent"
              ;
    $cmd = '';
}
elsif ($cmd eq 'dl') {
    $message = `$cgi_dir/nytbee_dl.pl '$uuid' '$screen_name'`;
    $cmd = '';
}
elsif ($cmd eq 'bn') {
    $bonus_mode = $bonus_mode? 0: 1;
    $donut_mode = $forum_mode = 0;
    $cmd = '';
}
elsif ($cmd eq 'dn') {
    $donut_mode = $donut_mode? 0: 1;
    $bonus_mode = $forum_mode = 0;
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
    $forum_mode = $forum_mode? 0: 1;
    $bonus_mode = $donut_mode = 0;
    $cmd = '';
}
elsif ($cmd eq 'im') {
    $show_RankImage = $show_RankImage? 0: 1;
    $cmd = '';
}
elsif ($cmd eq 'st') {
    redo_settings('st');
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
    my $nextra = grep { m{[$ext_sig]\z}xms } @found;
    my @rows;
    push @rows, Tr(td("Score")
                   . ($percent? td(): '')
                   . td($score));
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
                    my $m = @ok_words - @found + $nextra;
                    my $pl = $m == 1? '': 's';
                    $more .= ", $m more word$pl";
                }
            }
            $cols .= td(red('*') . $more);
        }
        push @rows, Tr($cols);
    }
    $message .= ul(table({ cellpadding => 4}, @rows));
    $cmd = '';
}
elsif ($cmd =~ m{\A d(p|r|5|[a-z]\d+|[a-z][a-z]|[-][a-z][a-z][a-z]) \z}xms) {
    do_define($1);
    $cmd = '';
}
elsif ($cmd =~ m{\A d([~][a-z]+=[a-z]+) \z}xms) {
    # undocumented - for the jumble table
    do_define($1);
    $cmd = '';
}
elsif ($cmd eq 'swa') {
    # add ALL puzzle words to the stash
    s/([a-z])$/$1!/ for @found;   # fun!
    $message = 'Stashed';
    $cmd = '';
}
elsif ($cmd eq 'sw') {
    # a no op - ignore
    $cmd = '';
}
elsif ($cmd =~ m{\A sw \s+ ([a-z ]*) \z}xms  # sw at the front
       ||
       $cmd =~ m{\A ([a-z ]*) \s+ sw? \z}xms # sw or s at the end
) {
    # adding words to the stash.
    # we first check the words.
    # give errors for unqualified words and
    # Extra words get added as normal.
    my $stash = $1;
    my @words = split ' ', $stash;
    my $nwords_stashed = 0;
    for my $w (@words) {
        if ($is_found{$w}) {
            if (grep { /\b$w!/ } @found) {
                $not_okay_words .= red(uc $w) . ": already stashed<br>";
            }
            elsif (my ($x) = grep { /\b$w[*+-]/ } @found) {
                my $type = $x =~ m{[-]\z}xms? 'Donut'
                          :$x =~ m{[+]\z}xms? 'Lexicon'
                          :                   'Bonus'
                          ;
                $message .= red(uc($w))
                         . " is a $type word not a puzzle word so it cannot be stashed!";
            }
            else {
                # we are stashing a puzzle word we already found
                @found = map { s{\A $w \z}{$w!}xms; $_; } @found;
                ++$nwords_stashed;
                # add to list for highlighting
                $is_new_word{$w} = 1;
                if ($pw_feedback == 0) {
                    $message .= ul(def_word(red(uc $w), $w)
                             . ': Puzzle word stashed -' 
                             .  word_score($w, $is_pangram{$w}));
                }
                elsif ($pw_feedback == 1) {
                    $points_added -= word_score($w, $is_pangram{$w});
                }
            }
        }
        else {
            $nwords_stashed += consider_word($w, 1);
        }
    }
    if ($nwords_stashed && $bonus_mode) {
        # we give this message because we are not
        # showing the Stash word list in Bonus mode.
        my $pl = $nwords_stashed == 1? '': 's';
        $not_okay_words .= "$nwords_stashed word$pl stashed<br>";
    }
    $n_minus = $nwords_stashed;     # for the possible On the Nose message
    $cmd = '';
}
elsif ($cmd eq '~pf') {
    # undocumented
    $message = "@found";
    $cmd = '';
}
elsif ($cmd eq 's45') {
    @found = map {
                my $l = length;
                my ($w) = m{([a-z]+)!}xmsi;
                 $l == 4        ? "$_!"
                : !$w && $l >= 5? $_
                : $l > 5        ? $w
                :                 $_;
             }
             @found;
    $show_BingoTable = 0;
    $message = "You can now strive for GN4L.";
    $cmd = '';
}
elsif (my ($gt, $item) =
     $cmd =~ m{\A \s* [#] \s*([>]?)(\d*|[a-z]?) \s* \z}xms
) {
    my @words = grep { !$is_found{$_} }
                @ok_words;
    if (! $item) {
        # no hints added
        $message .= scalar(@words) . '<br>';
    }
    elsif ($item =~ m{\A\d+\z}xms) {
        my $n = grep { $gt? length > $item: length == $item } @words;
        add_hints(1);
        $message .= $n . '<br>';
            # not sure why we need the <br>
    }
    else {
        my $n = grep { m{\A$item}xms } @words;
        add_hints(1);
        $message .= $n . '<br>';
    }
    $cmd = '';
}
elsif (   $cmd =~ m{\A d \s+ ([a-z ]+) \z}xms
       || $cmd =~ m{(\A [a-z ]{3,}) \s+ d \z}xms
                              # {3,} to protect against 'co d'
                              # being interpreted as a define request
) {
    # dictionary definitions of full words not clues
    my $words = $1;
    my @words = split ' ', $words;
    for my $word (@words) {
        my ($cmd, $label);
        if (in_stash($word)) {
            $cmd = $word;
            $label = 'UNstash';
        }
        # do not offer Stash for Extra words 
        elsif ($is_ok_word{$word}) {
            $cmd = "sw $word";
            $label = 'Stash';
        }
        my $the_definition = define($word, 1);
        my $the_word = $word;   # for the full definition
        # maybe change $the_word if the definition is ...???
        # we may add some other possibilities here...
        if ($the_definition =~ m{
                (
                    Common[ ]misspelling[ ]of[ ]
                    |
                    Alternative[ ]form[ ]of[ ]
                    |
                    Simple[ ]past[ ]tense[ ]and[ ]past[ ]participle[ ]of[ ]
                    |
                    Plural[ ]form[ ]of[ ]
                    |
                    Plural[ ]of[ ]
                    |
                    Present[ ]participle[ ]of[ ]
                )
                (\w+)
            }xmsi
        ) {
            $the_word = $2;
        }
        $message .= <<"EOM";
<br>
<span class='letter' style='cursor: pointer'
      onclick="full_def('$the_word');">\U$word\E</span>
EOM
        $message .= <<"EOM" if $cmd;
<span class=alink style='margin-left: 1in;'
      onclick="issue_cmd('$cmd');">$label</span>
EOM
        $message .= <<"EOM";
<a class=alink
   onclick='set_focus()'
   target=_blank
   style='margin-left: 1in;'
   href='https://google.com/search?q=$word'>
Search</a>
EOM
        $message .=  qq!<span class=cursor_black onclick="full_def('$the_word');">!
                 .  ul($the_definition)
                 .  '</span>'
                 ;
    }
    $message =~ s{\A <br>}{}xms;
    $cmd = '';
}
elsif ($cmd =~ m{\A g \s+ y \z}xms) {
    my @words = grep { !$is_found{$_} }
                @ok_words;
    add_hints(@words * 5);
    $cmd = "@words";    # as if they typed them
}
elsif ($cmd =~ m{\A c \s+ y \s*(a?) \z}xms) {
    my $all = $1;
    @found = $all? (): grep { /[*+-]\z/ } @found;
                       # leave the Extra words in place
                       # but include the stash words
    $nhints = 0;
    # do not clear $n_overall_hints
    $ht_chosen = 0;
    $tl_chosen = 0;
    $t3_chosen = 0;
    $jt_chosen = 0;
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
    my %extra_type = qw/
       ! Stash
       * Bonus
       + Lexicon
       - Donut
    /;
    FOUND:
    for my $w (@found) {
        my $x = $w;
        if ($x =~ s{([$ext_sig])\z}{}xms) {
            my $sigil = $1;
            push @rows, Tr(td({ class => 'gray' }, ucfirst $x),
                           td(''),
                           td(''),
                           td({ class => 'lt gray' },
                              "$space$extra_type{$sigil}"
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
                           td({ class => 'rt' }, $space.$tot),
                           td({ class => 'lt' }, $space.$rank_name),
                          );
        }
        if ($tot == $score_at_first_hint) {
            # yes == above
            push @rows, Tr(td({ colspan => 3 }, '<hr>'));
        }
    }
    $message .= table({ cellpadding => 2 }, @rows);
    my $nextra = grep { m{[$ext_sig]\z}xms } @found;
    my $more = @ok_words - (@found - $nextra);
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
                          qq!<span class=alink onclick="issue_cmd('$cpn');">!
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
elsif ($cmd =~ m{\A [~]fcp \s+ (.*)}xms) {
    # undocumented
    $message = `$cgi_dir/nytbee_fcp.pl $1`;
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
        push @rows, Tr(td("<a class=alink target=nytbee onclick='set_focus();'"
                        . " href='$log/cgi-bin/edit_cp.pl/$n'>CP$n</a>"),
                       td({ }, slash_date($href->{created})),
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
                      qq!<span class=alink onclick="issue_cmd('$p->[0]');">!
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
    my @dates = `$cgi_dir/nytbee_clue_dates.pl '$uuid'`;
    chomp @dates;
    if (!@dates) {
        $message .= '';
    }
    else {
        $message
            = 'Puzzles you clued:<br>'
            . table(
                  map {
                      Tr(td(qq!<span class=alink onclick="issue_cmd('$_');">!
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
    $message = `$cgi_dir/same_7.pl $seven $date @ok_words`;
    $cmd = '';
}
elsif ($cmd =~ m{\A ([bd])[>] \z}xms) {
    my $type = $1;
    my $c = $type eq 'b'? '*': '-';
    # bonus/donut words in increasing length
    my @words;
    for my $w (@found) {
        if ($w =~ m{\A (.*)[$c]\z}xms) {
            push @words, ucfirst $1;
        }
    }
    @words = map { $_->[1] }
             sort {
                $a->[0] <=> $b->[0]
                ||
                $a->[1] cmp $b->[1]
             }
             map { [ length, $_ ] }
             @words;
    my $prev_len = 0;
    for my $w (@words) {
        my $l = length $w;
        if ($l > $prev_len) {
            if ($message) {
                $message .= "</ul>";
            }
            $message .= $l . "<ul>";
            $prev_len = $l;
        }
        $message .= "$w<br>";
    }
    if ($message) {
        $message .= "</ul>";
    }
    $cmd = '';
}
elsif ($cmd =~ m{\A ft \s+ ([a-z]+) \z}xms) {
    my $word = $1;
    # when did this word first appear?
    my $dt = $first_appeared{$word};
    if ($dt) {
        $message .= qq!<span class=alink onclick="issue_cmd('$dt');">!
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
                   Tr(td(qq!<span class=alink onclick="issue_cmd('$_');">!
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
            Tr(td(qq!<span class=alink onclick="issue_cmd('$cpn');">!
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
    $hive = $hive == 1? 2: 1;
    $cmd = '';
}
elsif ($cmd =~ m{\A [~]le \s+ (\S{6}) \s* \z}xms) {
    # undocumented
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
my @found_puzzle_words = grep { !m/[$ext_sig]\z/xms } @found;
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
elsif ($date !~ m{\A CP }xms && $cmd =~ m{\A [~]lg \s+ (\S+) \z}xms) {
    # undocumented
    my $sn = $1;
    $message = `$cgi_dir/nytbee_log.pl -s $date '$sn'`;
    $cmd = '';
}
elsif ($date !~ m{\A CP }xms && $cmd eq 'lg') {
    $message = `$cgi_dir/nytbee_log.pl $date '$uuid11'`;
    $cmd = '';
}
elsif ($date !~ m{\A CP}xms
       && ($cmd eq 'ac' || $cmd eq 'mac' || $cmd =~ m{\A [~]ac \s+ (.*) \z}xms)
) {
    my $sn = $cmd eq 'mac'? lc $screen_name : lc $1;        # undocumented
    if ($date < '20221222') {
        $message = 'Activity monitoring began on December 22, 2022.';
    }
    else {
        $message = `$cgi_dir/nytbee_activity.pl $date '$colors{letter}' '$sn'`;
    }
    $cmd = '';
}
elsif ($cmd eq 'ft') {
    $first_time = 1;
    $cmd = '';
}
elsif (($uuid eq 'sahadev108!')
       && (my ($mode, $cp_num)
              = $cmd =~ m{\A [~]([+-])cp(\d+) \z}xms)
) {
    # undocumented
    my $fname = "$comm_dir/$cp_num.txt";
    if (! -f $fname) {
        $message .= "No such community puzzle: CP$cp_num";
    }
    else {
        my $cp_href = do $fname;
        $cp_href->{recommended} = $mode eq '+'? 1: 0;
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
                        td({class => 'lt'}, qq!<span class=alink onclick="issue_cmd('cp$p->{n}')">CP$p->{n}</span>!),
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

# to add - or remove...
sub words_to_add {
    my ($cmd) = @_;
    return $cmd =~ m{\A [-]?[a-z]{4,}}xms   # begins with a 4+ letter word
           && 
           $cmd !~ m{\s d \z}xms        # doesn't end with space d (define)
           &&
           $cmd !~ m{\A wl}xms          # not a wl... command
           ;                            # like wlps
}

if (words_to_add($cmd)) {
    @new_words = map {
                     lc
                 }
                 split ' ', $cmd;
    $cmd = '';      # so we stop asking ...
}

# they found a bonus, donut, or lexicon word
# if they don't yet have a screen name
# it's time to assign them one.
sub check_screen_name {
    if ($screen_name) {
        return;
    }
    my $name = $base[ rand @base ];
    my $i = 1;
    while (exists $screen_name_uuid{"$name$i"}) {
        ++$i;
    }
    $screen_name = "$name$i";
    $uuid_screen_name{$uuid11} = $screen_name;
    $screen_name_uuid{$screen_name} = $uuid11;
    #
    # dead code...
    #my $url = 'https://ultrabee.org/help.html#screen_names';
    #$message .= "<div class=red>"
    #         . "You have been assigned a screen name of $screen_name.<br>"
    #         . "You can change it with the SN command.<br>"
    #         . "Read all about screen names <a target=_blank href='$url'>here</a>."
    #         . "</div><p>"
    #         ;
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

sub in_wordnik {
    my ($word) = @_;
    my $json = get_html("https://api.wordnik.com/v4/word.json/$word/definitions?api_key=jtatm78lwq4i5ed4y0touh93ftt29832ti8o24bbh6ek5ta5l");
    if (! $json) {
        return 0;
    }
    my $aref = decode_json($json);
    for my $href (@$aref) {
        if (exists $href->{text}) {
            my $def = $href->{text};
            $def =~ s{[<][^>]*[>]}{}xmsg;
            $def =~ s{[&][#]39;}{'}xmsg;
            $def =~ s{$word}{'*' x length($word)}xmsegi;
            $def =~ s{[^[:ascii:]]}{}xmsg;
            $definition_of{$word} = $def;
            return 1;
        }
    }
    return 0;
}

# https://www.grammarly.com/blog/plural-nouns/
sub an_S_or_ES_word {
    my ($w) = @_;
    if ($w !~ m{s$}xmsi) {
        return 0;
    }
    $w =~ s{s$}{}xmsi;
    if (in_wordnik($w)) {
        return uc $w;
    }
    if ($w =~ m{(s|ss|sh|ch|x|z)e$}xmsi) {
        $w =~ s{e$}{}xms;
        if (in_wordnik($w)) {
            return uc $w;
        }
    }
    return 0;
}

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
            if (   $osx_usd_words_48{$w}
                || $first_appeared{$w}
                || $added_words{$w}
            ) {
                return "bonus";
            }
            elsif (in_wordnik($w)) {
                my $root = an_S_or_ES_word($w);
                if ($root && $w !~ m{less\z}xmsi) {
                    return "Sorry, this word is just a plural OR a 3rd person singular simple present indicative form of " . red($root) . ".";
                }
                else {
                    $added_words{$w} = 1;
                    return "bonus";
                }
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
        if (   $osx_usd_words_47{$w}
            || $first_appeared{$w}
            || $added_words{$w}
            || in_wordnik($w)
        ) {
            # we'll keep the word but not
            # count it for the score of the puzzle
            return 'donut';
        }
        return "does not contain: " . red($Center);
    }
    if (! exists $is_ok_word{$w}) {
        if (   $osx_usd_words_47{$w}
            || $added_words{$w}
            || in_wordnik($w)
        ) {
            # we'll keep the word but not
            # count it for the score of the puzzle
            $added_words{$w} = 1;
            return 'lexicon';
        }
        return "not in word list";
    }
    return '';      # the word is in the allowed list
}

sub p_word {
    my ($w, $stashed) = @_;
    def_word(red("\U$w\E"), $w)
    .  ": Puzzle word "
    . ($stashed? 'stashed': '+' . word_score($w, $is_pangram{$w}))
    . "<br>"
    ;
}

#
# check the word
# and either add it, stash it, or give an error message.
#
# very tricky - test it thoroughly
#
sub consider_word {
    my ($w, $stashing) = @_;
    my $mess = check_word($w);
    if (   $mess eq ''
        || $mess eq 'donut'
        || $mess eq 'lexicon'
        || $mess eq 'bonus'
    ) {
        if ($mess ne '') {
            # it's an extra word so we'll need
            # a screen name for the CW report.
            check_screen_name();
        }
        $is_new_word{$w} = 1;
        if ($stashing && in_stash($w)) {
            # do nothing
            $not_okay_words .= red(uc $w) . ": already stashed<br>";
        }
        elsif (! $is_found{$w} || in_stash($w)) {
            # if in the stash, take it out
            # unless we are stashing
            if (! $stashing && in_stash($w)) {
                @found = grep { $_ ne "$w!" } @found;
            }
            $is_found{$w} = 1;
            if ($mess eq 'donut') {
                my $own = own_word('donut', $date, $w);
                $not_okay_words .= "<span class=not_okay>"
                                .  def_word(uc($w), $w)
                                .  "</span>: Donut ${own}word $thumbs_up<br>"
                                .  pangram_check($w, 6);
                add_4word('donut', $date, $w);
                $w .= '-';
            }
            elsif ($mess eq 'lexicon') {
                my $own = own_word('lexicon', $date, $w);
                $not_okay_words .= "<span class=not_okay>"
                                .  def_word(uc($w), $w)
                                .  "</span>: Lexicon ${own}word $thumbs_up<br>"
                                .  pangram_check($w, 7);
                add_4word('lexicon', $date, $w);
                $w .= '+';
            }
            elsif ($mess eq 'bonus') {
                my $own = own_word('bonus', $date, $w);
                my $bingo = index($seven, substr($w, 0, 1)) < 0? 'Bingo ': '';
                my $super = length $w >= 7 && index($w, $center) >= 0?
                                'Super ': '';
                $not_okay_words .= "<span class=not_okay>"
                                .  def_word(uc($w), $w)
                                .  "</span>: ${bingo}${super}Bonus ${own}word $thumbs_up<br>"
                                .  pangram_check($w, 8, $seven);
                add_4word('bonus', $date, $w);
                $w .= '*';      # * in the found list marks bonus words
            }
            elsif ($stashing) {
                # it's an okay word
                # put it in the stash
                $is_new_word{$w} = 1;
                $is_found{$w} = 1; 
                if ($pw_feedback == 0) {        # Inline
                    $not_okay_words .= p_word($w, 1);
                }
                if ($is_pangram{$w}) {
                    my $perfect = length $w == 7? 'Perfect ': '';
                    $not_okay_words .= "${perfect}Pangram! $thumbs_up stashed<br>";
                }
                if (! in_stash($w)) {
                    $w .= '!';
                }
            }
            else {
                # a valid puzzle word
                if ($pw_feedback == 0) {
                    $not_okay_words .= p_word($w);
                }
                elsif ($pw_feedback == 1) {
                    $points_added += word_score($w, $is_pangram{$w});
                }
                if ($is_pangram{$w}) {
                    my $perfect = length $w == 7? 'Perfect ': '';
                    $not_okay_words .= "${perfect}Pangram! $thumbs_up<br>";
                }
                # it's a valid word in the allowed list
                # has this word completed a bingo?
                # analyze this before we add it to @found 
                my $bingo_score = 0;

                # ignore extra words
                my @found2 = grep { ! m{[$ext_sig]\z}xms } @found;
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
                        $bingo_score += 1;                
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
                            $bingo_score += 2;                
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
                                            .  "<p>"
                                            .  qq!<span class=pointer style='color: $colors{alink}' onclick="issue_cmd('SWA')">On to Max Bingo</span>!
                                            ;
                            $bingo_score += 4;                
                        }
                        if ($max) {
                            $not_okay_words .= 'AND with a MAXIMUM score! '
                                            .  ($thumbs_up x 4)
                                            .  "<p>"
                                            .  qq!<span class=pointer style='color: $colors{alink}' onclick="issue_cmd('S45');">On to GN4L</span>!
                                            # s45 = stash any four letter words
                                            # and unstash any 5 letter words
                                            ;
                            $bingo_score += 8;                
                        }
                        log_it("bingo $date $bingo_score $n_overall_hints");
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
        if (length $w >= 4) {
            # for some reason ow and boa would get added
            # without the length check
            # this is because this whole program is a big hack
            # that would benefit from a rethink.
            add_4word('incorrect', $date, $w);
        }
        # Report the error and make a link on the word to
        # do a web search for $w:
        #
        #    http://google.com/search?q=$w
        #
        $not_okay_words .= "<span class=not_okay>"
                        .  "<a target=_blank onclick='set_focus()'"
                        .  " href='https://google.com/search?q=$w'>"
                        .  "<span style='color: red'>" . uc($w) . "</span>"
                        .  "</a>"
                        .  "</span>: $mess<br>";
    }
    return $w =~ m{!\z}xms? 1: 0;
}

WORD:
for my $w (@new_words) {
    next WORD if $w eq '1w';        # hack!
    if (my ($xword) = $w =~ m{\A [-]([a-z]+)}xms) {
        # remove the word from the found list
        # do not stash it
        if ($is_found{$xword}) {
            my @new_found;
            my $char = '';
            for my $w (@found) {
                if ($w =~ m{\A $xword ([!*+-])? \z }xms) {
                    $char = $1;
                }
                else {
                    push @new_found, $w;
                }
            }
            @found = @new_found;
            delete $is_found{$xword};
            ++$n_minus;
            # puzzle feedback?
            # ! stash * bonus + lexicon - donut
            my $type = $char eq '' ? 'Puzzle'
                      :$char eq '!'? 'Stash'
                      :$char eq '*'? 'Bonus'
                      :$char eq '+'? 'Lexicon'
                      :              'Donut'
                      ;
            my $ws = '';
            if ($type eq 'Puzzle') {
                my $n = word_score($xword, $is_pangram{$xword});
                $ws = " -$n";
                $points_added -= $n;
                    # in case $pw_feedback is 1
            }
            if ($pw_feedback == 0) {
                $message .= ul(red(uc $xword)
                         . ": $type word removed$ws<br>");
            }
        }
        else {
            $not_okay_words = "<span class=not_okay>"
                            . uc($xword)
                            . "</span>: not a found word";
        }
        next WORD;
    }
    consider_word($w);
}

# now that we have added the new words...
# ??? is this right???  why is it called twice?
my $old_rank = $rank;
compute_score_and_rank();
if ($old_rank < $rank || ($n_minus > 0 && $score == $ranks[8]{value})) {
    my $gn4l = '';
    if ($rank >= 7) {
        $message .= ul( $rank == 7? "Amazing "   .  $thumbs_up
                       :$rank == 8? "Genius "    . ($thumbs_up x 2)
                       :            "Queen Bee " . ($thumbs_up x 3)
                    );
        if ($rank == 8) {
            my $npangrams = grep { $is_pangram{$_} } @found;
            my @four = grep { ! m{[$ext_sig]\z}xms && length == 4 } @found;
            if (! @four) {
                $message .= ul('And you did it without ANY 4 letter words! '
                               .  $thumbs_up);
                if ($score == $ranks[8]{value}) {
                    $message .= ul("On the Nose! <span style='font-size: 24pt'>&#128067</span> $thumbs_up");
                    $gn4l = 'GOTN';
                }
                else {
                    $gn4l = 'GN4L';
                }
                if ($npangrams == 0) {
                    $message .= ul('And with No Pangrams! &#128526; &#128588;');
                    $gn4l .= "-NP";
                }
            }
        }
    }
    log_it("rank$rank $date $gn4l");
}
if (! $prefix && ! $pattern && ! $limit && ! @words_found) {
    # the default when there are no restrictions
    @words_found = sort grep { !m/[$ext_sig]\z/xms } @found;
}

sub dlb_row {
    my ($name, $aref, $show_name) = @_;
    return '' unless @$aref;
    return Tr(($show_name? td({ class => 'dlb_name' }, "$name &nbsp;"): ()),
              td({ class => 'dlb mess' },
                 "@$aref "
               . span({ class => 'gray' }, scalar(@$aref))));
}

sub one_col {
    my ($name, $aref, $show_name) = @_;
    return '' unless @$aref;
    local $" = "<br>\n";
    return ($show_name? $name: '')
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
my $extra_words = '';
if (!$forum_mode && $show_WordList) {
    my @donut;
    my @lexicon;
    my @bonus;
    my @stash;
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
        elsif ($w =~ m{[!]\z}xms) {
            my $x = $w;
            $x =~ s{[!]\z}{}xms;
            push @stash, $x;
        }
    }
    if (!$order_found) {
        @donut   = sort @donut;
        @lexicon = sort @lexicon;
        @bonus   = sort @bonus;
        @stash   = sort @stash;
    }
    if ($w_cmd) {
        @donut   = restrict($w_cmd, \@donut);
        @lexicon = restrict($w_cmd, \@lexicon);
        @bonus   = restrict($w_cmd, \@bonus);
        @stash   = restrict($w_cmd, \@stash);
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
                   my $nchars = uniq_chars(lc $w);
                   my $s;
                   if ($nchars == 7) {
                       my $color = length $w == 7? 'purple': 'green';
                       $s = "<span class=$color>$uw</span>";
                   }
                   elsif ($is_new_word{lc $w}) {
                       $s = "<span class=new_word>$uw</span>";
                   }
                   else {
                       $s = $uw;
                   }
                   def_word($s, $w);
               } 
               @lexicon;
    # STASH
    @stash = map {
                   my $w = $_;
                   my $nchars = uniq_chars(lc $w);
                   my $uw = ucfirst $w;
                   my $s = $is_new_word{$w}?
                               "<span class=new_word>$uw</span>"
                          :$is_pangram{$w}?
                               length($w) == 7? "<span class=purple>$uw</span>"
                              :                 "<span class=green>$uw</span>"
                          :    $uw
                          ;
                   def_word($s, $w);
               } 
               @stash;
        
    if ($word_col) {
        $extra_words .= one_col('Stash:',   \@stash, 1  )
                if !$bonus_mode && !$donut_mode && $which_wl =~ /s/;
        $extra_words .= one_col('Lexicon:', \@lexicon, 1)
                if !$bonus_mode && !$donut_mode && $which_wl =~ /l/;
        $extra_words .= one_col('Donut:',   \@donut, !$donut_mode  )
                if $donut_mode || (!$bonus_mode && $which_wl =~ /d/);
        $extra_words .= one_col('Bonus:',   \@bonus, !$bonus_mode  )
                if $bonus_mode || (!$donut_mode && $which_wl =~ /b/);
        if ($extra_words) {
            $extra_words = "<br>$extra_words";
        }
    }
    else {
        $extra_words .= dlb_row('Stash:',   \@stash, 1)
                if !$bonus_mode && !$donut_mode && $which_wl =~ /s/;
        $extra_words .= dlb_row('Lexicon:', \@lexicon, 1)
                if !$bonus_mode && !$donut_mode && $which_wl =~ /l/;
        $extra_words .= dlb_row('Donut:',   \@donut, !$donut_mode)
                if $donut_mode || (!$bonus_mode && $which_wl =~ /d/);
        $extra_words .= dlb_row('Bonus:',   \@bonus, !$bonus_mode)
                if $bonus_mode || (!$donut_mode && $which_wl =~ /b/);
        if ($extra_words) {
            # convert rows to a table...
            $extra_words = "<!-- STASH LEXICON DONUT BONUS WORDS -->\n"
                         . table($extra_words);
            if ($donut_mode || $bonus_mode) {
                my $style = <<'ST';
<style>
.dlb {
    text-align: left;
    font-size: 18pt;
    width: 650px;
}
</style>
ST
                $extra_words = "$style<div class=extra_div>\n$extra_words</div>\n";
            }
            else {
                $extra_words = "<p>\n$extra_words";
            }
        }
    }
}
if ($bonus_mode && ! $mobile) {
    my @other = grep { !/[$seven]/ } 'a' .. 'z';
    my @bonus = grep { m{[*]\z}xms } @found;
    chop @bonus;    # the *
    my $all = join '~', '', @bonus;
        # the '' places a needed ~ at the front
    #$all =~ s{[$seven]}{}xmsg;
    my $lets = '<p>';
    for my $o (@other) {
        my $color;
        if (index($all, "~$o") >= 0) {
            $color = "green";  # Bingo Bonus
        }
        elsif (index($all, $o) >= 0) {
            $color = "lightgreen";  # Bonus
        }
        else {
            $color = $colors{letter};
        }
        $lets .= "<span style='color: $color'>\u$o</span> ";
    }
    $lets .= '<br>';
    for my $s (@seven) {
        my $color;
        if (index($all, "~$s") >= 0) {
            $color = "green";  # Bingo Bonus
        }
        else {
            $color = $colors{letter};
        }
        $lets .= "<span style='color: $color'>\u$s</span> ";
    }
    $extra_words = "$lets$extra_words";
}
my $bingo_table = '';
if (!$donut_mode && !$bonus_mode && $show_BingoTable) {
    $bingo_table = <<'EOH';
<!-- BINGO TABLE -->
EOH
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
                maxlen => 0,
                pangram => 0,
            };
        }
        my $l = length $w;
        my $pangram = $is_pangram{$w};
        my $sc = word_score($w, $pangram);
        my $href = $bingo_table{$c};
        if ($sc < $href->{min}) {
            $href->{min} = $sc;
            $href->{minlen} = $l;
        }
        if ($sc > $href->{max}) {
            $href->{max} = $sc;
            $href->{maxlen} = $l;
            $href->{pangram} = $pangram;
        }
    }
    my %first_found;
    for my $w (grep { !m{[$ext_sig]\z}xms } @found) {
        ++$first_found{uc substr($w, 0, 1)};
    }
    #       A  B  C  D  E  F  G
    # Min   4  4  4  5  6  4  4
    # Max   6  8  5 12  8  4  7
    #          *     *            (pangrams)
    my @rows;
    my @lets = sort keys %bingo_table;
    if (@lets == 7) {
        my $span = "<span class=pointer style='color: $colors{alink}'";
        # LETTERS
        push @rows, Tr(
                        td('&nbsp;'),
                        map {
                            my $color = $first_found{$_}? 'color: #8E008E': '';
                            td({ style => "width: 5mm; text-align: center; $color" }, $_);
                        }
                        @lets
                    );
        # MIN
        push @rows, Tr(
                        td('Min'),
                        map {
                            my $min = $bingo_table{$_}{minlen};
                            td($span
                               . qq! onclick="issue_cmd('D$_$min');">!
                               . $min
                               . "</span>"
                            );
                        }
                        @lets,
                    );
        # MAX
        push @rows, Tr(
                        td('Max'),
                        map {
                            my $max = $bingo_table{$_}{maxlen};
                            td($span
                               . qq! onclick="issue_cmd('D$_$max');">!
                               . $max
                               . "</span>"
                            );
                        }
                        @lets,
                    );
        # PANGRAMS
        push @rows, Tr(
                        td('&nbsp;'),
                        map {
                            td($bingo_table{$_}{pangram}?
                                   " <span class=red2>*</span>"
                                  :''
                            );
                        }
                        @lets,
                    );
        $bingo_table = ul(table({ cellpadding => 6}, @rows)) . '<p>';
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
    for my $w (grep { !m{[$ext_sig]\z}xms } @found) {
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
    $found_words = ul(table({ cellpadding => 2 }, sort @rows));
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
if ($bonus_mode || $donut_mode) {
    $found_words = '';
}
if (! $show_WordList || $which_wl !~ /p/) {
    $found_words = '';
}
else {
    $found_words = <<"EOH";
<!-- FOUND WORDS -->
$found_words
EOH
}

# we unfortunately may have determined the bingo
# status once before - see show_BingoTable above.
my %first_char;
for my $w (@ok_words) {
    my $c1 = substr($w, 0, 1);
    $first_char{$c1} = 1,
}
my $bingo = keys %first_char == 7? qq!, <a class=alink onclick="issue_cmd('BT');">Bingo</a>!: '';

# perhaps $cmd was not words to add after all...
# JON - move these!  Move lots of others as well.
# Put the words_to_add near the top!!
# first check to see if $cmd eq ''...
if ($cmd eq '1' || $cmd eq '51') {
    my @words = grep { !$is_found{$_} && ($cmd eq '1' || length >= 5) }
                @ok_words;
    if (@words) {
        add_hints(1);
        my $word = $words[ rand @words ];
        my $c = substr($word, 0, 1);
        my $l = length $word;
        my $n = grep { substr($_, 0, 1) eq $c && length == $l } @words;
        $message .= "\U$c$l" . ($n > 1? "-$n": '');
    }
    else {
        $message .= 'No more words.';
    }
    $cmd = '';
}
elsif ($cmd eq '2') {
    my @words = grep { !$is_found{$_}}
                @ok_words;
    if (@words) {
        add_hints(1);
        my $word = $words[ rand @words ];
        my $l2 = substr($word, 0, 2);
        my $n = grep { m{\A $l2}xms } @words;
        $message .= "\U$l2" . ($n > 1? "-$n": '');
    }
    else {
        $message .= 'No more words.';
    }
    $cmd = '';
}
elsif ($cmd eq '3') {
    my @words = grep { !$is_found{$_}}
                @ok_words;
    if (@words) {
        add_hints(1);
        my $word = $words[ rand @words ];
        my $l3 = substr($word, 0, 3);
        my $n = grep { m{\A $l3}xms } @words;
        $message .= "\U$l3" . ($n > 1? "-$n": '');
    }
    else {
        $message .= 'No more words.';
    }
    $cmd = '';
}
elsif ($cmd eq '52') {
    my @words = grep { !$is_found{$_} && length >= 5 }
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
elsif ($cmd eq '53') {
    my @words = grep { !$is_found{$_} && length >= 5}
                @ok_words;
    if (@words) {
        add_hints(1);
        my $word = $words[ rand @words ];
        my $l3 = substr($word, 0, 3);
        my $n = grep { m{\A $l3}xms } @words;
        $message .= "\U$l3" . ($n > 1? "-$n": '');
    }
    else {
        $message .= 'No more 5+ words.';
    }
    $cmd = '';
}
elsif ($cmd eq '5j') {
    my @words = grep { !$is_found{$_} && length >= 5}
                @ok_words;
    if (@words) {
        add_hints(1);
        my $word = $words[ rand @words ];
        $message .= uc jumble($word);
    }
    else {
        $message .= 'No more 5+ words.';
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
    # is GN4L possible?
    my $gn4l = '';
    my $tot = 0;
    my $np_tot = 0;
    for my $w (@ok_words) {
        my $lw = length $w;
        if ($lw > 4) {
            $tot += $lw;
            if ($is_pangram{$w}) {
                $tot += 7;
            }
            else {
                $np_tot += $lw;
            }
        }
    }
    my $genius = $ranks[8]{value};
    if ($tot < $genius) {
        $gn4l = ', ' . red("No GN4L");
    }
    elsif ($np_tot < $genius) {
        $gn4l = ', ' . red("No GN4L-NP");
    }
    if (! $show_Heading && $date !~ m{\A cp}xmsi) {
        $message .= date($date)->format("%B %e, %Y") . '<br>';
    }
    $message .= "Words: $nwords, Points: $max_score, "
             . "Pangrams: $npangrams$perfect$bingo$gn4l";
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
        if ($date >= 20210920) {
            my ($year, $month, $day) = unpack "A4A2A2", $date;
            $message .= "<a style='margin-left: .5in;' class=alink target=_blank href='https://www.nytimes.com/$year/$month/$day/crosswords/spelling-bee-forum.html#commentsContainer'>HiveMind</a>";
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
elsif ($cmd =~ m{\A (n?iw) \s+ ([a-z]+) \z}xms) {
    my $numeric = $1 eq 'niw';
    my $prefix = $2;
    open my $in, '<', "incorrect/$date";
    my %words;
    while (my $line = <$in>) {
        chomp $line;
        if ($line =~ m{\A $prefix}xms) {
            ++$words{$line};
        }
    }
    close $in;
    my @words = $numeric? (sort {
                               $words{$b} <=> $words{$a}
                               ||
                               $a cmp $b
                           }
                           keys %words)
               :          (sort keys %words)
               ;
    my @rows;
    for my $w (@words) {
        push @rows, Tr(td({ class => 'lt' }, $w),
                       td({ class => 'rt' }, $words{$w}),
                    );
    }
    $message .= table(@rows);
    $cmd = '';
}
elsif ($cmd =~ m{\A (n)?([dlbi])w \z}xms) {
    # second column of numbers is the # of people who found it
    # DW, LW, BW - sort by the word
    # NDW, NLW, NBW - sort by the numbers descending then the word
    # pangram (green), perfect pangram (purple)
    # word is skyblue if you found it
    # you can click on each word to get definition and
    # then on the definition to get full wordnik definition.
    #
    my $numeric = $1;
    my $let = uc $2;
    if ($date eq $ymd && $let ne 'I') {
        $message .= "Sorry, you cannot do \U$cmd\E for today's puzzle.<br>You will need to wait until tomorrow.";
    }
    else {
        my $name = { qw/ D donut L lexicon B bonus I incorrect/ }->{$let};
            # fun!  learned this at Aruba
        open my $in, '<', "$name/$date";
        my %words;
        my $total = 0;
        while (my $w = <$in>) {
            chomp $w;
            ++$words{$w};
            ++$total;
        }
        close $in;
        my $nwords = keys %words;
        my $pl = $nwords == 1? '': 's';
        $message .= "$nwords " . ' unique ' . ucfirst($name) . " word$pl<br>\n";
        $message .= "$total Total<p>";
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
            my $dw = $let eq 'I'? $w: def_word($w, $w);
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
elsif ($cmd eq 'top') {
    check_screen_name();
    untie %uuid_screen_name;
    untie %screen_name_uuid;
    untie %full_uuid;
    untie %cur_puzzles_store;
    my $nwords = @ok_words;
    my ($od, $ob, $ol) = own_counts();
    $message .= `$cgi_dir/nytbee_top.pl $date $nwords $seven '$screen_name' $od $ob $ol`;
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
        $message .= `$cgi_dir/nytbee_cw.pl $date $max $seven '$screen_name' $bonus_mode $donut_mode`;
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
elsif ($cmd eq 'bb') {
    my @bonus = sort grep { m{[*]\z}xms } @found;
    chop @bonus;
    my %bonus_starting_with = map { $_ => [] } 'a' .. 'z';
    for my $b (@bonus) {
        my $w = $b;
        $w =~ s{[$seven]}{}xmsg;    # the addition letter is all that is left
        my $c = substr($w, 0, 1);
        my $uc = uc $c;
        my $x = ucfirst $b;
        $x =~ s{$c}{<span class=red>$c</span>}xmsg;
        $x =~ s{$uc}{<span class=red>$uc</span>}xmsg;
        push @{$bonus_starting_with{substr($b, 0, 1)}}, ucfirst $x;
    }
    $cmd = '';
    $message = '';
    my $bb = 0;
    my @rows;
    for my $l ('a' .. 'z') {
        my @words = @{$bonus_starting_with{$l}};
        ++$bb if @words;
        my @color;
        if (index($seven, $l) >= 0) {
            @color = qw/ class green /;
        }
        push @rows, Tr(td({ valign => 'top', align => 'center', @color },
                          uc $l),
                       td({ class => 'lt mess'},
                          @words)
                      );
    }
    $message = table({ cellpadding => 5 }, @rows);
    $message .= '<p>';
    $message .= table(Tr(td('BB:'), td($bb)));
    $message = ul($message);
}
elsif ($cmd eq 'boa') {
    $cmd = '';
    my %bwords_with;
    for my $l (grep { !/[$seven]/ } 'a' .. 'z') {
        $bwords_with{$l} = [];
    }
    my @bonus = sort grep { m{[*]\z}xms } @found;
    chop @bonus;    # the *
    my %bb_lets;
    for my $bw (@bonus) {
        my $x = $bw;
        $x =~ s{[$seven]}{}xmsg;
        my $a = substr($x, 0, 1);
        if (substr($bw, 0, 1) eq $a) {
            $bb_lets{$a} = 1;
        }
        $bw = ucfirst $bw;
        $bw =~ s{([^$seven])}{<span class=red1>$1</span>}xmsgi;
        push @{$bwords_with{$a}}, $bw;
    }
    my $bb_score = scalar keys %bb_lets;
    my $boa_score = 0;
    my @rows;
    for my $l (sort keys %bwords_with) {
        my @words = @{$bwords_with{$l}};
        if (@words) {
            ++$boa_score;
        }
        push @rows, Tr(
                        td({ valign => 'top', style => 'text-align: center' },
                           uc $l),
                        td({ class => 'lt mess'},
                           "@words")
                      );
    }
    $message = table({ cellpadding => 5 }, @rows);
    $message .= '<p>';
    $message .= table(Tr(td('BOA:'), td($boa_score)));
    $message = ul($message);
}
# an undocumented cheat for Donut words
elsif ($cmd eq '~d') {
    my $donut_letters = $seven;
    $donut_letters =~ s{$center}{}xms;
    $cmd = '';
    $message = join '',
               map { "$_<br>\n" }
               `egrep -i '^[$donut_letters]{4,}\$' osx_usd_words-47.txt`;
}
# an undocumented cheat for Bonus words
elsif ($cmd =~ m{\A [~]b([a-z])\z}xmsi) {
    my $let = $1;
    $cmd = '';
    $message = join '',
               map { "$_<br>\n" }
               `egrep -i '^[$seven$let]{6,}\$' osx_usd_words-48.txt | grep $let`;
}
# an undocumented cheat for Bonus words of screen name with letter
elsif ($cmd =~ m{\A [~]b([a-z]) \s (\w+)\z}xmsi) {
    my $let = $1;
    my $screen_name = $2;
    $cmd = '';
    $message = `$cgi_dir/nytbee_bbx.pl $date $let $screen_name`;
}
elsif ($cmd eq '~wp') {
    $cmd = '';
    untie %uuid_screen_name;
    untie %full_uuid;
    untie %cur_puzzles_store;
    $message = `$cgi_dir/nytbee_wp.pl`;
}
elsif ($cmd eq 'ow') {
    $cmd = '';
    $message = 'These words were found only by you:<br><br><table>';
    for my $type (qw/ donut bonus lexicon /) {
        $message .= "<tr><td class=rt valign=top>\u$type:&nbsp;</td>";
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
elsif ($cmd eq 'id') {
    # show the $uuid so the user can save it
    # for later application with the 'ID ...' command
    $message .= $uuid . " <span id=uuid class=copied></span><script>copy_uuid_to_clipboard('$uuid');</script>";
                       # a clever invisible way to invoke
                       # javascript without a user click...
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
elsif ($cmd =~ m{\A sn \s+ (.+) \z}xms) {
    my $new_name = lc $1;
    if ($new_name =~ m{[<>'"]}xms) {
        $message = qq!Sorry, the characters &lt; &gt;, ', and " are not allowed in a screen name."!
    }
    elsif ($new_name =~ m{\s}xms) {
        $message = "Sorry, spaces are not allowed in a screen name.";
    }
    else {
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
    }
    $cmd = '';
}
elsif ($cmd) {
    $message = uc(red($cmd)) . ": unknown command";
    $cmd = '';
}

my $image = '';
if (7 <= $rank && $rank <= 9) {
    my $name = lc $ranks[$rank]->{name};
    $name =~ s{\s.*}{}xms;  # for queen bee
    $image = "<img src=$log/pics/$name.png>";
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
    $nhints, $n_overall_hints, $all_pangrams, $ht_chosen,
    $tl_chosen, $t3_chosen, $jt_chosen, $rank, $score_at_first_hint,
    @found
    ;
$cur_puzzles_store{$uuid} = Dumper(\%cur_puzzles);  # the key point #2
untie %cur_puzzles_store;

my $has_message = 0;
if ($message) {
    $message .= '<p>';
    $has_message = 1;
}

#
# disabled for now
#

# 18d7edac-6fee-11ed-a97e-8c36b52268c0
# 0123456789012345678901234567890
#           1         2         3
sub long_form {
    my ($uuid) = @_;
    return substr($uuid,  8, 1) eq '-'
        && substr($uuid, 13, 1) eq '-'
        && substr($uuid, 18, 1) eq '-'
        && substr($uuid, 23, 1) eq '-'? 1: 0;
}

# is the screen_name base+num?
sub assigned_sn {
    my ($sn) = @_;
    if (! $sn) {
        return 1;
    }
    my $base = join '|', @base;
    return $sn =~ m{\A ($base)\d+ \z}xms? 1: 0;
}

my $lf = long_form($uuid);
my $sn = assigned_sn($screen_name);
if (0 && ($lf || $sn)       # not any more...
    && keys %cur_puzzles > 2
    && @found > 3
) {
    # present a different page.
    # ask for a screen_name and an identity string.
    # make sure to keep their settings and current puzzles.
    # and exit;
    system("$cgi_dir/new_sn_is.pl '$screen_name' '$sn' '$uuid' '$lf' '$date'");
    exit;
}

# now to display everything
# cgi-bin/style.css?
my $num_msgs = '';
if (my $nm = $num_msgs{$date}) {
    $num_msgs = " <span class=red>$nm</span>";
}

my $forum_s = $forum_mode? '<s>Forum</s>': 'Forum';
my $heading = $show_Heading? <<"EOH": '';
<div class=float-child1>
    UltraBee<br>$show_date
</div>
<div class=float-child2>
     <img width=53 src="data:image/png;base64,$ext_logo_base64" onclick="navigator.clipboard.writeText('$cgi/nytbee.pl/$date');show_copied('logo');set_focus();" class=link><br><span class=copied id=logo></span>
</div>
<div class=float-child3>
    <div style="text-align: center"><a class=alink target=nytbee_help onclick="set_focus();" href='$log/help.html#toc'>Help</a>&nbsp;&nbsp;<a target=_blank class=alink href='$log/cmds.html'>Cmds</a><br><a class='alink' onclick="issue_cmd('F');" title='F'>$forum_s $num_msgs</a></div>
</div>
<br><br><br>
EOH

my $letters = '';
if ($hive == 1) {        # bee hive honeycomb
    $letters = svg_hex($mobile, $donut_mode);
    $letters =~ s{LET0}{$donut_mode? ' ': $Center}xmsge;
    for my $i (1 .. 6) {
        $letters =~ s{LET$i}{$six[$i-1]}xmsg;
    }
    $letters =~ s{CENTER_HEX}{$colors{center_hex}}xmsg;
    my $s = $donut_mode? 'center_hex': 'center_text';
    $letters =~ s{CENTER_TEXT}{$colors{$s}}xmsg;
    $letters =~ s{DONUT_HEX}{$colors{donut_hex}}xmsg;
    $letters =~ s{DONUT_TEXT}{$colors{donut_text}}xmsg;
    $letters =~ s{BACKGROUND}{$colors{background}}xmsg;

    if (index($seven, 'i') >= 0) {
        $letters =~ s{
            <text([^>]*)
                x="([\d.]+)
                ([^>]*)>I<
        }
        {qq!<text$1x="! . ($2+6) . "$3>I<"}xmse;
    }

    my $st = "style='color: $colors{alink}'";
    if ($mobile) {
        # enter, wordlets, delete, define
        # all positioned absolutely as well
# subroutines inside an if.  why not? :)
sub click_td {
    my ($l, $bonus, $bingo) = @_;
    my $color = $bingo? 'green'
              : $bonus? 'lightgreen'
              :         $colors{letter};
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
            # been used in a Bonus word and which start
            # with the additional letter
            my %used_in_bonus;
            my %bingo_bonus;
            for my $w (grep { m{[*]\z}xms } @found) {
                my $b = $w;
                $b =~ s{[$seven]}{}xmsg;
                my $c = substr($b, 0, 1);
                $used_in_bonus{$c}++;
                $bingo_bonus{$c}++ if substr($w, 0, 1) eq $c;
            }
            my $row1 = Tr(map({ click_td(uc,
                                    $used_in_bonus{$_}, $bingo_bonus{$_}) }
                              @blets[0 .. 9]));
            my $row2 = Tr(map({ click_td(uc,
                                    $used_in_bonus{$_}, $bingo_bonus{$_}) }
                              @blets[10 .. 18]));
            my $bonus_table = <<"EOH";
<table cellpadding=0 cellspacing=10>
$row1
$row2
</table>
EOH
            $letters .= <<"EOH";
<span class=lets id=lets></span>
<span class='pos11 alink' onclick="stash_lets();">Stash</span>
<span class='pos21 alink' onclick="sub_lets();">Enter</span>
<span class='pos22 alink' onclick="del_let();">Delete</span>
<span class='pos23 alink' onclick="issue_cmd('CW');">Standings</span>
<span class='pos12 alink' onclick="issue_cmd('OW');">Own</span>
<span class='pos13 alink' onclick="issue_cmd('BN');"><s>Bonus</s></span>
<span class=bonus_lets>$bonus_table</span>
EOH
        }
        elsif ($donut_mode) {
            $letters .= <<"EOH";
<span class=lets id=lets></span>
<span class='pos11 alink' onclick="stash_lets();">Stash</span>
<span class='pos21 alink' onclick="sub_lets();">Enter</span>
<span class='pos22 alink' onclick="del_let();">Delete</span>
<span class='pos23 alink' onclick="issue_cmd('CW');">Standings</span>
<span class='pos12 alink' onclick="issue_cmd('OW');">Own</span>
<span class='pos13 alink' onclick="issue_cmd('DN');"><s>Donut</s></span>
<span class='pos32 cursor_black'>
EOH
        }
        else {
            # not Donut, not Bonus
            my $forum_s = $forum_mode? '<s>Forum</s>': 'Forum';
            my $define = $no_define? '': <<"EOH";
<span class='pos12 cursor_black' $st onclick="issue_cmd('DR');">Define</span>
EOH
            $letters .= <<"EOH";
<span class='pos11 cursor_black' $st onclick="stash_lets();">Stash</span>
$define
<span class='pos13 cursor_black' $st onclick="issue_cmd('DN');">Donut</span>
<span class='pos21 cursor_black' $st onclick="sub_lets();">Enter</span>

<span class=lets id=lets></span>

<span class='pos22 cursor_black' $st onclick="del_let();">Delete</span>
<span class='pos23 cursor_black' $st onclick="issue_cmd('BN');">Bonus</span>
<span id=pos31 class='pos31 cursor_black' $st onclick="issue_cmd('TOP');">Top</span>
<span id=pos32 class='pos32 cursor_black'><a class='cursor_black' $st target=_blank href='$log/help.html#toc'">Help</a></span>
<span id=pos33 class='pos33 cursor_black' $st onclick="issue_cmd('F');">$forum_s $num_msgs</span>
EOH
        }
    }
    else {
        # not mobile - still need span id=lets
        $letters .= "<span class=lets id=lets></span>\n";
        # and we have the various links as well
        if ($show_Links) {
            my $donut = $donut_mode? '<s>Donut</s>': 'Donut';
            my $bonus = $bonus_mode? '<s>Bonus</s>': 'Bonus';
            my $define = $no_define? '': <<"EOH";
<span class='pos11 cursor_black alink' $st onclick="issue_cmd('DR');" title='DR'>Define</span>
EOH
            $letters .= <<"EOH";
$define
<span class='pos12 cursor_black alink' $st onclick="issue_cmd('OW');" title='OW'>Own</span>
<span class='pos21 cursor_black alink' $st onclick="issue_cmd('TOP');" title='TOP'>Top</span>
<span class='pos22 cursor_black alink' $st onclick="issue_cmd('CW');" title='CW'>Standings</span>
<span class='pos31 cursor_black alink' $st onclick="issue_cmd('DN');" title='DN'>$donut</span>
<span class='pos32 cursor_black alink' $st onclick="issue_cmd('BN');" title='BN'>$bonus</span>
EOH
            if ($bingo) {
                my $bgo = $show_BingoTable? '<s>Bingo</s>': 'Bingo';
                $letters .= <<"EOH";
<span class='pos33 cursor_black alink' $st onclick="issue_cmd('BT');" title='BT'>$bgo</span>
EOH
            }
        }
    }
}
elsif ($hive == 2) {    # straight line letters
    if ($mobile) {
        # &nbsp; below to keep the line displayed.
        # otherwise it is omitted.
        my $top = $show_Heading? 90: 0;
        my $style = <<"EOS";
style="width: 100%; color: green; font-size: 60pt; position: absolute; top: $top; text-align: center;"
EOS
        $letters = "<div $style id=lets></div>";
        $letters .= "<table style='margin-top: .7in; width: 100%'><tr>\n";
        for my $c (@seven_let) {
            unless ($donut_mode && $c eq uc $center) {
                my $class = $c eq uc $center? 'red2 biglet': 'biglet';
                $letters .= "<td class='$class' width='14.28%'>"
                         .  qq!<span onclick="add_let('$c')">$c</span>!
                         .  "</td>";
            }
        }
        $letters .= "</tr></table>\n";
        my $the_cmd = $donut_mode? 'CW'       : $no_define? 'TOP': 'DR';
        my $the_lab = $donut_mode? 'Standings': $no_define? 'Top': 'Define';
        $letters .= "<table style='width: 100%; margin-bottom: 10mm'><tr>"
                 .  "<td class='h3cmd alink' onclick='del_let()'>Delete</td>"
                 .  qq!<td class='h3cmd alink' onclick="issue_cmd('H');">Hexagon</td>!
                 .  qq!<td class='h3cmd alink' onclick="issue_cmd('$the_cmd');">$the_lab</td>!
                 .  "<td class='h3cmd alink' onclick='sub_lets()'>Enter</td>"
                 .  "</tr></table>"
                 ;
    }
    else {
        $letters = "<pre style='font-family: Arial; font-size: 40pt'>\n  ";
        my $sp = '&nbsp;' x 2;
        for my $c (@seven_let) {
            if ($c eq uc $center) {
                if (! $donut_mode) {
                    $letters .= "<span class=red2>$c$sp</span> ";
                }
            }
            else {
                $letters .="$c$sp";
            }
        }
        $letters .= "</pre>";
    }
}

my $hint_table_list = '';
if (! ($forum_mode || $bonus_mode || $donut_mode)
    && ($ht_chosen || $tl_chosen || $t3_chosen || $jt_chosen)
) {
    my @words = grep { ! $is_found{$_} } @ok_words;
    if (@words) {
        $hint_table_list = `$cgi_dir/tables.pl $ht_chosen $tl_chosen $t3_chosen $jt_chosen $colors{alink} \U@words`;
    }
}

sub graphical_status {
    my ($plus_numbers) = @_;
    my $ind1 = 2;
    my $ind2 = 28;
    my $between_lines = 22;
    my $between_dots = 11;
    my $dotr1 = 3;
    my $dotr2 = 5;
    my $col_let = $colors{letter};
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
    my $rainbow_width = 14;
    my $stash_rainbow_width = (2/3)*$rainbow_width;
    my $mark_height = 7;
    my $width = $ind2 + $between_dots*($nwords-1) + 26;
        # 26 extra to accomodate a plus sign + at the end of the hints
    my $height = (($bingo? 1: 0) + ($nhints? 1: 0) + 3) * 23;
               #    b                 h             pws
    $html = <<"EOH";
<!-- GRAPHICAL STATUS -->
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
        $html .= qq!<g onclick="issue_cmd('BT')">!;
            # the g element of SVG is for grouping
        my %first_found;
        for my $w (grep { !m{[$ext_sig]\z}xms } @found) {
            ++$first_found{uc substr($w, 0, 1)};
        }
        $html .= "<text x=$ind1 y=$y class=glets fill=$col_let>b</text>\n";
        my $x = $ind2;
        for my $c (map { uc } @seven) {
            my ($color, $class) = ($col_let, 'glets');
            if ($first_found{$c}) {
                ($color, $class) = ('#8E008E', 'bold_glets');
            }
            $html .= "<text x=$x y=$y class=$class fill=$color>$c</text>\n";
            $x += 20;
        }
        $html .= "</g>";
        $y += $between_lines;
    }

    $html .= qq!<g onclick="issue_cmd('F7')">!;
    $html .= "<text x=$ind1 y=$y class=glets fill=$col_let>p</text>\n";
    my $x = $ind2;
    $y -= 4;
    my $npp = 0;        # number of perfect pangrams
    for my $p (@pangrams) {
        if (length $p == 7) {
            ++$npp;
        }
    }
    my $npangrams_found = 0;
    my $npangrams_stashed = 0;
    my $npp_found = 0;
    my $npp_stashed = 0;
    for my $w (@found) {
        if ($is_pangram{$w}) {
            ++$npangrams_found;
            if (length $w == 7) {
                ++$npp_found;
            }
        }
        else {
            my $x = $w;
            $x =~ s{!\z}{}xms;
            if ($is_pangram{$x}) {
                ++$npangrams_stashed;
                if (length $x == 7) {
                    ++$npp_stashed;   
                }
            }
        }
    }
    $npp -= $npp_found + $npp_stashed;
    for my $i (1 .. $npangrams_found) {
        $html .= "<circle cx=$x cy=$y r=$dotr2 fill=#00C0C0></circle>\n";
        if ($i <= $npp_found) {
            $html .= "<circle cx=$x cy=$y r=2 fill=red></circle>\n";
        }
        $x += $between_dots;
    }
    for my $i (1 .. $npangrams_stashed) {
        $html .= "<circle cx=$x cy=$y r=$dotr2 fill=#AAF0F0></circle>\n";
        if ($i <= $npp_stashed) {
            $html .= "<circle cx=$x cy=$y r=2 fill=red></circle>\n";
        }
        $x += $between_dots;
    }
    for my $i (1 .. ($npangrams - ($npangrams_found+$npangrams_stashed))) {
        $html .= "<circle cx=$x cy=$y r=$dotr1 fill=$col_let></circle>\n";
        if ($i <= $npp) {
            $html .= "<circle cx=$x cy=$y r=2 fill=red></circle>\n";
        }
        $x += $between_dots;
    }
    $html .= "</g>";
    $y += 4;
    $y += $between_lines;

    my $w_ind = $ind1-2;
    $html .= qq!<g onclick="issue_cmd('I')">!;
    $html .= qq!<text x=$w_ind y=$y class=glets fill=$col_let>w</text>\n!;
    $x = $ind2;
    $y -= 4;
    my $nfound = grep { !m{[$ext_sig]\z}xms } @found;
    my @stash_words = map { s/!\z//; $_; } grep { m{!\z}xms } @found;
    my $nstash = @stash_words;
    my $stash_score = 0;
    for my $w (@stash_words) {
        $stash_score += word_score($w, $is_pangram{$w});
    }
    for my $i (1 .. $nfound) {
        $html .= "<circle cx=$x cy=$y r=$dotr2 fill=green></circle>\n";
        $x += $between_dots;
    }
    for my $i (1 .. $nstash) {
        $html .= "<circle cx=$x cy=$y r=$dotr2 fill=#70aa70></circle>\n";
        $x += $between_dots;
    }
    for my $i ($nfound+$nstash+1 .. $nwords) {
        $html .= "<circle cx=$x cy=$y r=$dotr1 fill=$col_let></circle>\n";
        $x += $between_dots;
    }
    $html .= "</g>";
    $y += 4;
    $y += $between_lines;

    $html .= "<text x=$ind1 y=$y class=glets fill=$col_let>s</text>\n";

    # a black line from 0 to max_score
    $y -=5; # centered on the S
    my $max_x = $ind2 + ($nwords-1)*$between_dots;
    my $x1 = $ind2;
    $html .= "<line x1=$x1 y1=$y x2=$max_x y2=$y stroke=$col_let stroke-width=1></line>\n";

    # colored ranks between the percentages
    # but only up to the score %
    my @pct = (0, 2, 5, 9, 15, 25, 40, 50, 70, 100);
    my $score_pct = ($score/$max_score)*100;
    my $full_score_pct = (($score + $stash_score)/$max_score)*100;
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
    #
    # and if there are words in the stash...
    #
    if ($nstash) {
        PCT:
        for my $i (0 .. $#pct-1) {
            my $x1 = $ind2 + ($pct[$i]/100)*($max_x - $ind2);
            if ($full_score_pct < $pct[$i+1]) {
                my $x2 = $ind2 + ($full_score_pct/100)*($max_x - $ind2);
                $html .= "<line x1=$x1 y1=$y x2=$x2 y2=$y stroke='#$color[$i]' stroke-width=$stash_rainbow_width></line>\n";
                last PCT;
            }
            my $x2 = $ind2 + ($pct[$i+1]/100)*($max_x - $ind2);
            $html .= "<line x1=$x1 y1=$y x2=$x2 y2=$y stroke='#$color[$i]' stroke-width=$stash_rainbow_width></line>\n";
        }
    }

    # vertical marks between ranks
    my $y1 = $y-$mark_height;
    my $y2 = $y+$mark_height;
    for my $pct (@pct) {
        my $x1 = $ind2 + ($pct/100)*($max_x - $ind2);
        my $x2 = $x1;
        $html .= "<line x1=$x1 y1=$y1 x2=$x2 y2=$y2 stroke=$col_let stroke-width=1></line>\n";
    }
    $y += 4;
    $y += $between_lines;

    # hints
    if ($nhints) {
        $html .= "<text x=$ind1 y=$y class=glets fill=$col_let>h</text>\n";
        $x = $ind2;
        $y -= 5;
        HINT:
        for my $i (1 .. abs($nhints)) {
            if ($i > $nwords) {
                $html .= "<text x=$x y=$y class=glets fill=$col_let>+</text>\n";
                last HINT;
            }
            else {
                $html .= "<circle cx=$x cy=$y r=$dotr1 fill=$col_let></circle>\n";
            }
            $x += $between_dots;
        }
    }

    $html .= "</svg>\n";
    if ($plus_numbers) {
        $nfound += $nstash;
        my $pct = int($nfound*100/$nwords);
        my $diff = $nwords - $nfound;
        my $sc = $score + $stash_score;
        my $spct = int($sc*100/$max_score);
        my $sdiff = $max_score - $sc;
        my $pl = $nfound == 1? '': 's';
        my $spl = $sc == 1? '': 's';
        my $hpl = $nhints == 1? '': 's';
        my $space = '&nbsp;' x 1;
        my $rt = { style => 'text-align: right'};
        my $lf = { style => 'text-align: left'};
        my @rows;
        my $stashed_points = $sc - $score;
        my $sts = $stashed_points != 1? 's': '';
        push @rows,
            Tr(td($rt, $nfound), 
               td("word$pl of"),
               td($rt, $nwords),
               td($rt, "$space$pct%"),
               td($rt, "$space$diff"),
               td('more to find'),
            ),
            Tr(td($rt, $sc), 
               td("point$spl of"),
               td($rt, $max_score),
               td($rt, "$space$spct%"),
               td($rt, "$space$sdiff"),
               td('more to find'),
            ),
            Tr(td({ colspan => 2, style => 'text-align: left ' },
                  "score $score"),
               td({ colspan => 4, style => 'text-align: left ' },
                  "$stashed_points point$sts in stash"))
            ;
            if ($nhints) {
                my @cols;
                push @cols, td($rt, $nhints),
                            td($lf, "hint$hpl");
                if ($score != 0) {
                      push @cols,
                           td({ colspan => 6, style => 'text-align: left' },
                              sprintf("hints/score: %.2f", $nhints/$score)
                           );
                }
                push @rows, Tr(@cols);
            }
        $html .= table({ cellpadding => 1 }, @rows);
    }
    return $html . "<p>";
}

my $status =
    ($bonus_mode || $donut_mode || $status_display == 3)? ''
   :$status_display == 1   ? graphical_status()
   :$status_display == 2   ? graphical_status(1)
   :                         "Score: $score $rank_image $disp_nhints<p>";
my $css       = $mobile? $ext_mobile_css: $ext_desktop_css;
my $fastclick = $mobile? $ext_fastclick: '';
my $new_words_size = $mobile? 30: 40;
my $row1_top  = 40 + ($show_Heading? 79: 0);
my $row2_top  = 90 + ($show_Heading? 79: 0);
my $lets_top   = 135 + ($show_Heading? 79: 0);
my $bonus_lets_top   = 185 + ($show_Heading? 79: 0);
my $row3_top = 190 + ($show_Heading? 79: 0);
my $forum_html = '';
if ($forum_mode) {
    $forum_html = `$cgi_dir/show_forum.pl $date '$screen_name' $forum_post_to_edit '$colors{bg_input}' '$colors{text_input}'`;
    $bingo_table =
    $found_words =
    $extra_words =
    $status = '';
}
my $title_date = $date =~ m{\A CP}xms? $date
                :                      'NYT '
                                       . date($date)->format('%B %e, %Y');
my $mobile_bonus = '';
if ($mobile && $bonus_mode) {
    # ackk.  too many places have code to get @bonus.
    # we need to initialize a puzzle object
    # and a game object and then have methods
    # to get seven, found, bonus, center, etc
    #
    my @bonus = grep { m{[*]\z}xms } @found;
    chop @bonus;    # the *
    my $all = join '~', '', @bonus;
    $mobile_bonus .= '&nbsp;' x 3;
    for my $s (@seven) {
        my $color = index($all, "~$s") >= 0? 'green': $colors{letter};
        $mobile_bonus .= '&nbsp;'
                      . "<span style='color: $color'>"
                      . uc($s)
                      . '</span>'
                      ;
    }
}
my $flash_script = '';
if ($pw_feedback == 1
    && ($points_added != 0 || $n_hints_added != 0)
    && $hive != 2
) {
    my $s = '';
    if ($points_added) {
        $s = (($points_added > 0)? '+': '')
           . $points_added;
    }
    if ($n_hints_added) {
        $s = "+$n_hints_added hints";
    }
    $flash_script = <<"EOJ";
<script>
init();
add_let('$s');
setTimeout(() => {
    lets.innerHTML = "";
}, 1300);
</script>
EOJ
}
print <<"EOH";
<html>
<head>
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
<link rel="manifest" href="/site.webmanifest">
<meta charset='UTF-8'>
<title>UltraBee - $title_date</title>
<style>
body {
    background: $colors{background};
    color: $colors{letter};
}
.table_div {
    position: $position_attr;
    left: 610px;
    top: 50px;
}
.extra_div {
    position: $position_attr;
    left: 540px;
    top: 50px;
}
.letter {
    color: $colors{letter};
}
.alink {
    color: $colors{alink};
    cursor: pointer;
    font-size: 16pt;
}
/* the 2 row x 3 col grid at the top when in mobile mode */
.pos11 {
    position: absolute;
    left: 320;
    top: $row1_top;
}
.pos12 {
    position: absolute;
    left: 420;
    top: $row1_top;
}
.pos13 {
    position: absolute;
    left: 520;
    top: $row1_top;
}
.pos21 {
    position: absolute;
    left: 320;
    top: $row2_top;
}
.pos22 {
    position: absolute;
    left: 420;
    top: $row2_top;
}
.pos23 {
    position: absolute;
    left: 520;
    top: $row2_top;
}
.pos31 {
    position: absolute;
    left: 320;
    top: $row3_top;
}
.pos32 {
    position: absolute;
    left: 420;
    top: $row3_top;
}
.pos33 {
    position: absolute;
    left: 520;
    top: $row3_top;
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
$css
</style>
$ext_script
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
<input type=hidden name=show_Links value=$show_Links>
<input type=hidden name=mobile_Device value=$mobile_Device>
<input type=hidden name=show_WordList value=$show_WordList>
<input type=hidden name=show_BingoTable value=$show_BingoTable>
<input type=hidden name=bonus_mode value=$bonus_mode>
<input type=hidden name=donut_mode value=$donut_mode>
<input type=hidden name=which_wl value=$which_wl>
<input type=hidden name=forum_mode value=$forum_mode>
<input type=hidden name=show_RankImage value=$show_RankImage>
$letters
<div style="width: 640px">$message</div>
<input type=hidden
       name=hidden_new_words
       id=hidden_new_words
>
<input class=new_words
       type=text
       size=$new_words_size
       style="background: $colors{bg_input}; color: $colors{text_input};"
       id=new_words
       name=new_words
       autocomplete=off
>$mobile_bonus
<p>
$bingo_table
$found_words
$extra_words
<p>
$status$hint_table_list
$forum_html
</form>
</body>
$show_clue_form
$fastclick
$flash_script
</html>
EOH
