#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Std;
my %opts;
getopts('Dd:', \%opts);

sub D {
    if ($opts{D}) {
        print "@_\n";
        <STDIN>;
    }
}

our $clear = $^O eq 'MSWin32'? 'cls': 'clear';
our $dir   = defined $opts{d}? $opts{d}
            :$^O eq 'MSWin32'? 'nytbee_data'        # in current directory
            :                  "$ENV{HOME}/.nytbee";
if (! (-d $dir && -w $dir)) {
    if (! mkdir $dir) {
        die "Cannot make puzzle directory: $dir\n";
    }
}
my $arch_fname = "$dir/archive.txt";
my $cgi = 'http://logicalpoetry.com/cgi-bin';
my $offline;
my $last_shell_command;
my $start_time = time();

sub we_are_offline {
    if (! defined $offline) {
        my $data = `curl -sk $cgi/nytbee/20191020`;   # my 70th birthday
        $offline = $data? 0: 1;
    }
D "offline = $offline";
    return $offline;
}
my $keep = 0;
my $status_file = "$dir/status.txt";
my %status;
    # key=date8, value= (p if all pangrams found or ' ') . $rank
if (-r $status_file) { 
    open my $in, '<', $status_file;
    while (my $line = <$in>) {
        chomp $line;
        my ($date8, $s) = $line =~ m{\A (\d+)(..) \z}xms;
        $status{$date8} = $s;
    }
}
my %archive;       # many puzzles going back to 7/29/2018
my $last_arch_dt;  # last date in the archive
my @archive;       # ordered array for rand...

sub load_archive {
    if (-r $arch_fname) {
        D "reading archive file";
        open my $in, '<', $arch_fname;
        %archive = map {
                       chomp;
                       # yyyymmdd ...
                       # 0123456789
                       $last_arch_dt = substr($_, 0, 8);
                       $last_arch_dt => substr($_, 9)
                   }
                   <$in>;
        close $in;
        return;
    }
    D "no archive file to read";
}

# the variables that comprise a puzzle
# i.e. a puzzle object attributes
my $show_date;
my $date8;
my $save_fname;
my $log_fname;
my $log;
my $elapsed_time;
my @words;
my $seven;
my @seven;
my @six;        # @seven sans $center
my $center;
my %found;
my @found;      # words found in order
my $score;
my $table_shown = 0;
my $assists;
my $rank;       # index into @ranks
my $all_pangrams_found;
my $max_points;
my @ranks;       # list of hashes (name, value)
my @rank_pct;    # percent of max needed
my %is_valid_word;
my %is_pangram;
my %twolets;
my %sums;
my $max_len = 0;
my $bingo = 0;
my $nperfect = 0;

sub get {
    my ($fh) = @_;
    my $s = <$fh>;
    chomp $s;
    $s =~ s{ \A .* : \s+ }{}xms;
    return $s;
}

sub Log {
    my ($what, $time) = @_;
    if ($time) {
        my ($min, $hour) = (localtime)[1,2];
        if ($hour > 12) {
            $hour -= 12;
        }
        printf {$log} "%d:%02d ", $hour, $min;
    }
    print {$log} $what;
    if ($time) {
        print {$log}"\n";
    }
}

# input parameter is either:
# empty
# rand
# 4/3/19
# 4/3/2019
# 20200904
# 5/4       ( current year )
#
# puzzle sources:
# on/off line
# archive present
# saved files
#
# this is really tricky.  many cases.
# specific date or random
# do we have a saved file for the date?
# offline, online
# do we have an archive file?
# have we already loaded the archive file yet?
# if rand, did we choose a random date
#     that we already have a saved file for?
#
sub new_puzzle {
    my ($pdate, $no_print) = @_;

    if ($date8 && $log) {
        # close out the current puzzle
        Log 'pause', 1;
        close $log;
    }
    $pdate ||= '';
    D "pdate = '$pdate'";
    my ($year, $month, $day);
    my $data;

    if (!$pdate) {
        ($year, $month, $day) = (localtime())[5, 4, 3];
        $year += 1900;
        ++$month;
        D "current date is $year, $month, $day";
    }
    elsif ($pdate eq 'rand') {
        DATE:
        while (1) {
            load_archive();  # lazy loading if needed
            if (we_are_offline()) {
                D "we are offline";
                if (! $last_arch_dt) {
                    D "no archive";
                    print "*no random puzzles when offline and no archive*\n";
                    if (! @words) {
                        # we are just starting
                        exit;
                    }
                    return;
                }
            }
            if ($last_arch_dt) {
                # we do have the archive file
                if (! @archive) {
                    D "initializing archive array";
                    # but not the ordered archive array
                    # so create it
                    @archive = sort keys %archive;
                }
                my $rand_dt = $archive[rand @archive];
                ($year, $month, $day) = $rand_dt =~ m{
                    \A (\d\d\d\d) (\d\d) (\d\d)
                }xms;
                D "random from archive: $year, $month, $day";
                $data = $archive{"$year$month$day"};
                D "we have data";
            }
            else {
                # no archive and we are online so ask for a random puzzle
                D "asking curl to get random puzzle date";
                my $rand_dt = `curl -sk $cgi/rand_nytbee`;
                ($year, $month, $day, $data) = $rand_dt =~ m{
                    \A (\d\d\d\d) (\d\d) (\d\d) \s+ (.*)
                }xms;
                D "got $year, $month, $day and data";
            }
            if (! -f "$dir/$year$month$day.txt") {
                D "a good random date we don't have it already";
                # we don't have it already have in our storage.
                last DATE;
            }
            # loop to get another random one
        }
    }
    elsif ($pdate =~ m{\A (\d+)/(\d+) \z}xms) {
        ($month, $day) = ($1, $2);
        ($year) = (localtime())[5];
        $year += 1900;
    }
    elsif ($pdate =~ m{\A (\d+)/(\d+)/(\d+) \z}xms) {
        ($month, $day, $year) = ($1, $2, $3);
        $year += 2000 if $year < 100;
    }
    elsif ($pdate =~ m{\A (\d\d\d\d) (\d\d) (\d\d) \z}xms) {
        ($year, $month, $day) = ($1, $2, $3);
    }
    else {
        print "invalid date: $pdate\n";
        if (! @words) {
            # we are just starting
            exit;
        }
        else {
            return;
        }
    }
    D "we have a date: $year $month $day";

    $date8 = sprintf "%4d%02d%02d", $year, $month, $day;
    if (-f "$dir/$date8.txt") {
        # better to have a hash %G $G{assists}, etc??
        # nah, syntactially awkward?  i don't think in objects...
        # object is not a synonym for good
        #
        D "we have saved file with data plus cur state of solve";
        $save_fname = "$dir/$date8.txt";
        $log_fname = "$dir/${date8}_log.txt";
        open my $in, '<', $save_fname
            or die "cannot open $save_fname: $!\n";
        @words = split ' ', get($in);
        %is_valid_word = map { $_ => 1 } @words;
        $max_points = get($in);

        $seven = get($in);
        @seven = split //, $seven;
        $center = get($in);
        @six = grep { $_ ne $center } @seven;

        $score = get($in);
        $table_shown = get($in);
        $assists = get($in);
        $elapsed_time = get($in);
        $rank = get($in);
        $all_pangrams_found = get($in);
        @found = split ' ', get($in);
        %found = map { $_ => 1 } @found;
        %is_pangram = map { $_ => 1 } split ' ', get($in);
        close $in;
        set_cur_status();
    }
    else {
        D "no saved file";
        # we may already have $data if $pdate was 'rand'
        if (! $data) {
            D "get data from archive or online";
            if (! $last_arch_dt) {
                load_archive();
            }
            $data = $archive{$date8};
            if ($data) {
                D "found in archive";
            }
            else {
                D "no archive for $date8";
                # not in archive
                if (we_are_offline()) {
                    D "we are offline cannot get data for $date8";
                    if (! $pdate && $last_arch_dt) {
                        # we asked for the current date
                        # return the latest archived date
                        D "return latest archive date";
                        print "Since we are offline we can't get today's puzzle.\n";
                        print "Instead we'll use the last puzzle in the archive.\n";
                        print "Hit return to continue ...";
                        <STDIN>;
                        new_puzzle($last_arch_dt);
                        return;
                    }
                    my @saved = <$dir/[0-9]*.txt>;
                    if (@saved) {
                        my ($date8) = $saved[-1] =~ m{(\d+)}xms;
                        print "Since we are offline we can't get today's puzzle.\n";
                        print "Instead we'll use the last saved puzzle: ",
                              slash_date($date8), "\n";
                        print "Hit return to continue ...";
                        <STDIN>;
                        new_puzzle($date8);
                        return;
                    }
                    else {
                        print "*we are offline, no archive, no saved files*\n";
                        print "*so no way to get puzzle for ", slash_date($date8), "*\n";
                        if (! @words) {
                            # we are just starting
                            exit;
                        }
                        return;
                    }
                }
                else {
                    D "using curl to get $date8";
                    $data = `curl -sk $cgi/nytbee/$date8`;
                    if (! $pdate && -f $arch_fname) {
                        D "saving today's puzzle in archive\n";
                        open my $out, '>>', $arch_fname;
                        print {$out} "$date8 $data\n";
                        close $out;
                    }
                }
            }
        }
        if (! $data || $data eq "no puzzle\n") {
            printf "Sorry, no puzzle for this date: %d/%d/%d.\n",
                   $month, $day, $year;
            if (! @words) {
                # we are just starting
                exit;
            }
            return;
        }

        #
        # we have $date8 and $data
        # make all the other initializations
        #
        $save_fname = "$dir/$date8.txt";
        $log_fname = "$dir/${date8}_log.txt";
        my ($s, $words) = split /\s*[|]\s*/, $data;
        @words = split ' ', $words;
        %is_valid_word = map { $_ => 1 } @words;
        my @pangrams;
        ($seven, $center, @pangrams) = split ' ', $s;

        @seven = split //, $seven;
        @six = grep { $_ ne $center } @seven;

        %is_pangram = map { $_ => 1 } @pangrams;

        # Maximum number of points
        $max_points = 0;
        for my $w (@words) {
            my $l = length $w;
            $max_points += ($l == 4? 1: $l) + ($is_pangram{$w}? 7: 0);
        }

        @found = ();
        %found = ();
        $rank = 0;
        $all_pangrams_found = 0;
        $score = 0;
        $assists = 0;
        $elapsed_time = 0;
        $table_shown = 0;
        $status{$date8} = ' 0';
    }

    # final initializations
    init_ranks();
    init_word_table();
    system($clear) unless $keep || $no_print;
    $show_date = slash_date($date8);
    save_state();
    if (-f $log_fname) {
        open $log, '>>', $log_fname;
        Log 'resume', 1;
    }
    else {
        open $log, '>', $log_fname;
        Log 'start', 1;
    }
    printf "$show_date\n" unless $no_print;
}

sub init_word_table {
    %sums = ();
    %twolets = ();
    $max_len = 0;
    WORD:
    for my $w (@words) {
        my $l = length($w);
        if ($max_len < $l) {
            $max_len = $l;
        }
        if ($found{$w}) {
            next WORD;
        }
        my $c1 = substr($w, 0, 1);
        my $c2 = substr($w, 0, 2);
        ++$sums{$c1}{$l};
        ++$twolets{$c2};
    }
    $bingo = 1;
    CHAR:
    for my $c (@seven) {
        if (! exists $sums{$c}) {
            $bingo = 0;
            last CHAR;
        }
    }
    $nperfect = 0;
    for my $p (keys %is_pangram) {
        if (length $p == 7) {
            ++$nperfect;
        }
    }
}

sub show_word_table {
    print "$show_date\n";
    print "words: ", scalar(@words), ", max points: $max_points\n";
    print "pangrams: ", scalar(keys %is_pangram); 
    if ($nperfect) {
        print " ($nperfect Perfect)";
    }
    if ($bingo) {
        print ", BINGO";
    }
    print "\n\n";
    print "     ";
    for my $l (4 .. $max_len) {
        printf "%3d", $l;
    }
    print " Sum\n";
    for my $c (sort @seven) {
        print "  \U$c: ";
        my $tot = 0;
        for my $l (4 .. $max_len) {
            my $n = $sums{$c}{$l};
            if ($n) {
                printf "%3d", $n;
                $tot += $n;
            }
            else {
                print "  -";
            }
        }
        printf " %3d\n", $tot;
    }
    my $tot_words = 0;
    print "Sum: ";
    for my $l (4 .. $max_len) {
        my $tot = 0;
        for my $c (@seven) {
            $tot += ($sums{$c}{$l} || 0);
        }
        printf "%3d", $tot;
        $tot_words += $tot;
    }
    printf " %3d\n", $tot_words;
}

sub show_two_letters {
    # we do not print ones with zero
    my @two = grep {
                  $twolets{$_}
              }
              sort
              keys %twolets;
    #print "\n" if @two;
    TWO:
    for my $i (0 .. $#two) {
        if ($twolets{$two[$i]} == 0) {
            next TWO;
        }
        print "\U$two[$i]-$twolets{$two[$i]}";
        if ($i < $#two
            && substr($two[$i], 0, 1) ne substr($two[$i+1], 0, 1)
        ) {
            print "\n";
        }
        else {
            print " ";
        }
    }
    print "\n" if @two;
}

sub prompt {
    print "\n";
    print ' ', uc "  $six[0]   $six[1]\n";
    print ' ', uc "$six[2]   $center   $six[3]\n";
    print ' ', uc "  $six[4]   $six[5]\n\n";
    print '> ';
}

sub show_found {
    my ($alphabetic, $prefix) = @_;
    $prefix ||= '';
    my @found_words =  @found;
    if ($alphabetic) {
        @found_words = sort @found_words;
    }
    if ($prefix) {
        @found_words = grep {
                           m{\A $prefix}xmsi
                       }
                       @found_words;
    }
    # upper case the first  letter and mark the pangrams
    @found_words = map {
                       ucfirst
                   }
                   map {
                       $is_pangram{$_}? length == 7? "$_**": "$_*"
                      :                 $_
                   }
                   @found_words;
    my $nwords = @found_words;
    my $pl = $nwords == 1? '': 's';
    print "$nwords word$pl\n";
    while (@found_words) {
        print join('  ', splice(@found_words, 0, 7)), "\n";
    }
}

sub save_state {
    $elapsed_time += (time() - $start_time);
    $start_time = time();
    open my $out, '>', $save_fname
        or die "cannot create $save_fname: $!";
    print {$out} <<"EOF";
words: @words
max points: $max_points
seven: $seven
center: $center
score: $score
table shown: $table_shown
assists: $assists
elapsed time: $elapsed_time
rank: $rank
all pangrams found: $all_pangrams_found
found: @found
EOF
    print {$out} "pangrams: ", join(' ', keys %is_pangram), "\n";
    close $out;
}

sub save_status {
    open my $out, '>', $status_file;
    for my $dt (sort keys %status) {
        print {$out} "$dt$status{$dt}\n";
    }
    close $out;
}

sub wrap {
    my ($s) = @_;
    # tidy up $s
    $s =~ s{[&]\w+;}{}xmsg;
    $s =~ s{\s{2,}}{ }xmsg;
    $s =~ s{\s*[.]\s*\z}{}xms;  # d told
    $s =~ s{">}{}xmsg;
    $s =~ s{—}{}xmsg;
    $s =~ s{\A \s*}{}xmsg;
    my $printed = 0;
    my $margin = " ";
    while ($s) {
        my $i = index($s, ' ', 50);
        if ($i < 0) {
            print $margin if $printed;
            print $s;
            return;
        }
        print $margin if $printed;
        print substr($s, 0, $i), "\n";
        $printed = 1;
        $s = substr($s, $i);
    }
    
}

# if no definition
# drop a final d or a final ed
# or ly?????
# and mark it as such
# the online dictionaries often give many different 
# definitions - let's just show 3 at the most.
# that's enough.  or maybe just 1?
# or all if Dcmd.
sub define {
    my ($word, $Dcmd, $dont_tally_assists) = @_;

    my ($html, @defs);

    # merriam-webster
    print "merriam-webster\n" if $Dcmd;
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
        $def =~ s{\s+ \z}{}xms;     # trailing space
        $def =~ s{<[^>]*>}{}xmsg;   # strip tags
        $def =~ s{.*:\s+}{}xms;
    }
    if (! @defs) {
        # collins
        print "collins\n" if $Dcmd;
        $html = `curl -skL https://www.collinsdictionary.com/dictionary/english/$word`;
        # grab the one at the top
        @defs = $html =~ m{og:description.*?:(.*?)[|]}xms;
    }
    if (! @defs) {
        # oxford/lexico
        print "oxford\n" if $Dcmd;
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
        $d =~ s{$word}{$stars}xmsgi;    # hide the word
        if ($seen{$d}++) {
            next DEF;
        }
        push @tidied_defs, $d;
    }
    if (! $Dcmd) {
        @tidied_defs = splice @tidied_defs, 0, 3;
    }
    for my $d (@tidied_defs) {
        print "- ";
        wrap($d);
        print "\n";
    }
    if (@tidied_defs && ! $dont_tally_assists) {
        ++$assists;
    }
    print "======\n";
}

sub reveal {
    my ($word, $nlets, $beg_end) = @_;
    my $lw = length $word;
    if ($nlets > $lw) {
        $nlets = $lw;
    }
    if (! $beg_end) {
        return substr($word, 0, $nlets)
             . ('-' x ($lw-$nlets))
    }
    my $c2 = int($nlets/2);
    my $c1 = $nlets - $c2;
    my $cu = $lw - $nlets;
    return substr($word, 0, $c1)
           . ('-' x $cu)
           . substr($word, $lw-$c2)
           ;
}

sub init_ranks {
    @ranks = (
        { name => 'Beginner',   value => 0 },
        { name => 'Good Start', value => int(.02*$max_points + 0.5) },
        { name => 'Moving Up',  value => int(.05*$max_points + 0.5) },
        { name => 'Good',       value => int(.08*$max_points + 0.5) },
        { name => 'Solid',      value => int(.15*$max_points + 0.5) },
        { name => 'Nice',       value => int(.25*$max_points + 0.5) },
        { name => 'Great',      value => int(.40*$max_points + 0.5) },
        { name => 'Amazing',    value => int(.50*$max_points + 0.5) },
        { name => 'Genius',     value => int(.70*$max_points + 0.5) },
        { name => 'Queen Bee',  value =>$max_points },
    );
    @rank_pct = (
        0, 2, 5, 8, 15, 25, 40, 50, 70, 100
    );
}

sub set_cur_status {
    my $all = 1;
    PG:
    for my $pg (keys %is_pangram) {
        if (! $found{$pg}) {
            $all = 0;
            last PG;
        }
    }
    $status{$date8} = ($all? 'p': ' ') . $rank;
}

sub slash_date {
    my ($dt) = @_;      #yyyymmdd
    return sprintf "%02d/%02d/%02d",
                   substr($dt, 4, 2),
                   substr($dt, 6, 2),
                   substr($dt, 2, 2),
                   ;
}

sub show_puzzles {
    my ($cmd) = @_;    #  l or L
    my $n = 0;
    for my $dt (sort keys %status) {
        ++$n;
        printf "%2d ", $n;
        print $dt eq $date8? '*': ' ';
        my ($p, $r) = split //, $status{$dt};
        printf "%s %s", slash_date($dt), $p;
        if ($cmd eq 'L') {
            if (open my $in, '<', "$dir/$dt.txt") {
                my $x1 = <$in>;
                my $x2 = <$in>;
                my $lets = uc get($in);
                my $center = uc get($in);
                close $in;
                chomp $lets;
                chomp $center;
                print " $lets $center";
            }
        }
        print " $ranks[$r]->{name}\n";
    }
}

sub rank_achieved {
    print "\n*$ranks[$rank]->{name}*\n";
    Log "*$ranks[$rank]->{name}* " . summary();
}

sub summary {
    my $esecs = $elapsed_time + time()-$start_time;
    my $mins = int($esecs/60);
    my $secs = $esecs % 60;
    my $pl = $assists == 1? '': 's';
    return sprintf("%d:%02d", $mins, $secs) . " with $assists assist$pl\n";
}

# execution begins
$SIG{QUIT} = $SIG{INT} = sub {
    save_state();
    print "\n";
    exit;
};
new_puzzle($ARGV[0]);

print "Enter h for help.\n";
COMMAND:
while (1) {
    prompt();
    my $word = <STDIN>;
    if (!$word) {
        print "\n";
        next COMMAND;
    }
    chomp $word;
    $word =~ s{\A\s+|\s+\z}{}xmsg;
    if ($word eq 'c') {
        print "Clearing the puzzle.\n";
        print "Are you sure? y/n "; 
        my $answer = <STDIN>;
        if ($answer =~ m{\A y}xmsi) {
            %found = ();
            @found = ();
            $score = 0;
            $table_shown = 0;
            $assists = 0;
            $elapsed_time = 0;
            $rank = 0;
            $all_pangrams_found = 0;
            init_word_table();
            $status{$date8} = ' 0';
            save_state();
            open $log, '>', $log_fname;
            Log 'start', 1;
        }
        system($clear) unless $keep;
        next COMMAND;
    }
    elsif ($word eq 'C') {
        print "Clearing ALL puzzles.\n";
        print "Are you sure? y/n "; 
        my $answer = <STDIN>;
        if ($answer =~ m{\A y}xmsi) {
            unlink <$dir/[0-9]*.txt $dir/status.txt>;
            %status = ();
            new_puzzle();       # today
        }
        next COMMAND;
    }
    elsif ($word eq 'g') {
        print "Giving up.\n";
        print "Are you sure? y/n "; 
        my $answer = <STDIN>;
        if ($answer =~ m{\A y}xmsi) {
            system($clear) unless $keep;
            my @temp = @words;
            while (@temp) {
                my @words = splice @temp, 0, 7;
                for my $w (@words) {
                    print ucfirst($w), $is_pangram{$w}? length $w == 7? '**'
                                                       :                '*'
                                       :                 '',
                          '  ';
                }
                print "\n";
            }
            $assists += 100;
            Log "* g - $assists\n";
            # then what?
        }
        else {
            system($clear) unless $keep;
        }
        next COMMAND;
    }
    elsif ($word eq 'k') {
        $keep = !$keep;
    }
    system($clear) unless $keep;
    if ($word eq 'k') {
        ;
    }
    elsif ($word !~ m{\S}xms) {
        ;
    }
    elsif ($word eq 'V') {
        # 1.0 - no V at all
        # 1.1 - V command
        #       fatal error when offline and archive present
        #       word: when d <word>
        #       lga - assists are logged
        #       x more words added if Genius rank
        #       2 issues with logging assists
        print "version: 1.1\n";
        next COMMAND;
    }
    elsif ($word eq 'h') {
        print <<'EOF';
h  Show this Help
H  How to play
p  Permute the 6 non-center letters
w  Words found in alphabetical order
W  Words found in the order they were found
s  Score - including rank and number of assists
r  Rankings
a  Assist commands
o  Other commands
n  New puzzle from random date
l  List current puzzles
n<num>  Switch to puzzle #num
P  Enter Pangram Mode
q  Quit - the words found will be remembered
EOF
    }
    elsif ($word eq 'H') {
print <<'EOF';
Create words using the 7 letters from the 'hive'.

Words must contain at least 4 letters.
Words must include the center letter.
Letters can be used more than once.

The allowed words do not include words that are
obscure, hyphenated, or proper nouns.
No cussing either, sorry.

Score points to increase your rating.
4-letter words are worth 1 point each.
Longer words earn 1 point per letter.
Each puzzle includes at least one 'pangram'
which uses every letter. These are worth
7 extra points.
EOF
    }
    elsif ($word eq 'a') {
        print <<'EOF';
t       Hints table and two letter hints
t1      Hints table
t2      Two letter hints
1       Random entry from the hints table
2       Random two letter hint
v 3 xy  Reveal 3 letters of words beginning with xy
v 4 x9  Reveal 4 letters of words of length 9 beginning with x
v 1 p   Reveal 1 letter of the pangrams
d xy    Define words beginning with xy
d x6    Define words of length 6 beginning with x
d p     Define pangrams

There may not be definitions for every word.
With d and v words already found are skipped.
Spaces in d and v commands are optional v4x9 = v 4 x9
The command e is like v but you'll see letters
at the beginning and End of the word.
EOF
    }
    elsif ($word eq 'o') {
print <<'EOF';
A     Download the Archive and pangrams for offline play.
n <date>   New puzzle from the given date
lg    Show the timestamped log in 25 line pages.
      Return goes to the next page, q quits.
lga   Show log with assists.
w <prefix> Show found words starting with a prefix.
k     Toggle clearing the screen or not.
      Useful to Keep text so you can scroll back.
d <word>   Define the word - no assist tallied.
D ... Like d but show all definitions instead of just 3.
c     After confirmation Clear the puzzle and start afresh.
C     After confirmation Clear all saved puzzles.
g     After confirmation Give up and show all words.
x<num>  Remove (eXclude or eXcise or X-out) puzzle #num.
R     Show Rankings with percentage of maximum.
S <word> Search for the word in the archive.
f     Find other puzzles with the same 7 letters.
L     List current puzzles with the 7 outer letters and center.
!...  Execute a system command - like 'date'.
EOF
    }
    elsif ($word eq 'q') {
        save_state();
        save_status();
        Log $rank == 9? 'end': 'pause', 1;
        close $log;
        exit;
    }
    elsif ($word eq 't') {
        show_word_table();
        print "\n";
        show_two_letters();
        if (!($table_shown & 3 == 3)) {
            $table_shown |= 3;
            $assists += 15;
            Log "* t - $assists\n";
        }
    }
    elsif ($word eq 't1') {
        show_word_table();
        if (!($table_shown & 1)) {
            $assists += 10;
            $table_shown |= 1;
            Log "* t1 - $assists\n";
        }
    }
    elsif ($word eq 't2') {
        show_two_letters();
        if (!($table_shown & 2)) {
            $assists += 5;
            $table_shown |= 2;
            Log "* t2 - $assists\n";
        }
    }
    elsif ($word eq 's') {
        my $nwords = keys %found;
        print scalar(keys %found), " word", ($nwords == 1? '': 's'), "\n";
        print "$score point", ($score == 1? '': 's'), "\n";
        my $pl = $assists == 1? '': 's';
        print "$assists assist$pl\n";
        print "$ranks[$rank]->{name}\n";
    }
    elsif ($word eq 'p') {
        # permute
        my @new;
        push @new, splice @six, rand @six, 1 while @six;
        @six = @new;
    }
    elsif ($word eq 'w') {
        show_found(1);
    }
    elsif ($word eq 'W') {
        show_found(0);
    }
    elsif ($word =~ m{\A ([wW]) \s+ (\S+)}xms) {
        show_found($1 eq 'w', $2);
    }
    elsif (lc $word eq 'l') {
        show_puzzles($word);
    }
    elsif ($word eq 'r') {
        my $more = 0;
        printf "  %10s %3d - $ranks[$rank]->{name}\n\n", "  Score", $score;
        for my $r (0 .. $#ranks) {
            printf "%d %10s %3d", $r, $ranks[$r]->{name}, $ranks[$r]->{value};
            my $n = $ranks[$r]->{value} - $score;
            if ($r == $rank) {
                print "  ***";
            }
            if (! $more && $n > 0) {
                print "  $n more needed";
                $more = 1;
            }
            print "\n";
        }
        if ($rank == 8) {
            my $nmore = @words - @found;
            my $pl = $nmore == 1? '': 's';
            print ' 'x18, "$nmore more word$pl\n";
        }
    }
    elsif ($word eq 'R') {
        # not easy to do both r and R together...
        my $more = 0;
        printf "  %10s      %3d - $ranks[$rank]->{name}\n\n", "Score", $score;
        for my $r (0 .. $#ranks) {
            printf "%d %10s %3d%% %3d",
                   $r, $ranks[$r]->{name},
                   $rank_pct[$r], $ranks[$r]->{value}
                   ;
            my $n = $ranks[$r]->{value} - $score;
            if ($r == $rank) {
                print "  ***";
            }
            if (! $more && $n > 0) {
                print "  $n more needed";
                $more = 1;
            }
            print "\n";
        }
        if ($rank == 8) {
            my $nmore = @words - @found;
            my $pl = $nmore == 1? '': 's';
            print ' 'x23, "$nmore more word$pl\n";
        }
    }
    elsif (my ($xcmd, $xterm)
        = $word =~ m{
              \A ([dD]) \s* (\w\s*\d+|p|\w\w) \s* \z
          }xms
    ) {
        if (we_are_offline()) {
            print "*no definitions when offline*\n";
            next COMMAND;
        }
        #
        # definition
        #
        my $Dcmd = $xcmd eq 'D';
        if ($xterm eq 'p') {
            # define all pangrams
            my @w = grep {
                        ! $found{$_}
                    }
                    sort
                    keys %is_pangram;
            if (@w) {
                print "pangrams:\n";
                for my $p (@w) {
                    define($p, $Dcmd);
                }
                Log "* $xcmd p - $assists\n";
            }
        }
        elsif (my ($let, $len) = $xterm =~ m{\A ([a-z])\s*(\d+) \z}xms) {
            if (index($seven, $let) < 0) {
                print "*illegal definition command*\n";
            }
            else {
                my @w = grep {
                            length == $len
                            && m{\A $let}xms
                            && ! $found{$_}
                        }
                        @words;
                if (@w) {
                    print "$let$len:\n";
                    for my $w (@w) {
                        define($w, $Dcmd);
                    }
                    Log "* $xcmd $let$len - $assists\n";
                }
            }
        }
        elsif ($xterm =~ m{\A \w\w \z}xms) {
            if (! exists $twolets{$xterm}) {
                for my $w (keys %found) {
                    if (substr($w, 0, 2) eq lc $xterm) {
                        print "*no words you haven't found yet begin with $xterm*\n";
                        next COMMAND;
                    }
                }
                print "*no words begin with $xterm*\n";
            }
            else {
                my @w = grep {
                            m{\A $xterm}xms
                            && ! $found{$_}
                        }
                        @words;
                if (@w) {
                    print "$xterm:\n";
                    for my $w (@w) {
                        define($w, $Dcmd);
                    }
                    Log "* $xcmd $xterm - $assists\n";
                }
            }
        }
        else {
            print "*illegal definition command*\n";
        }
    }
    elsif (my ($dD, $def_word)
               = $word =~ m{\A ([dD]) \s+ ([a-z]+) \s* \z}xmsi
    ) {
        if (we_are_offline()) {
            print "*no definitions when offline*\n";
            next COMMAND;
        }
        my $Dcmd = $dD eq 'D';
        print "$def_word:\n";
        define(lc $def_word, $Dcmd, 1);
        # no assists tallied
    }
    elsif (my ($cmd, $nlets, $term)
        = $word =~ m{\A ([ve]) \s* (\d+) \s* (.*) \z }xms
    ) {
        #
        # reveal
        #
        my $beg_end = $cmd eq 'e';
        if (my ($let, $len) = $term =~ m{([a-z])\s*(\d+)}xmsi) {
            $let = lc $let;
            if (index($seven, $let) < 0) {
                print "*illegal reveal command*\n";
            }
            else {
                my @w = grep {
                            length == $len
                            && m{\A $let}xms
                            && ! $found{$_}
                        }
                        @words;
                if (@w) {
                    for my $w (@w) {
                        print reveal($w, $nlets, $beg_end), "\n";
                    }
                    $assists += @w;
                    Log "* $cmd $nlets $let$len - $assists\n";
                }
            }
        }
        elsif ($term eq 'p') {
            my @w = grep {
                        ! $found{$_}
                    }
                    sort
                    keys %is_pangram;
            if (@w) {
                for my $p (@w) {
                    print reveal($p, $nlets, $beg_end), "\n";
                }
                $assists += @w;
                Log "* $cmd p - $assists\n";
            }
        }
        elsif (length $term == 2) {
            $term = lc $term;
            if (! exists $twolets{$term}) {
                print "*no words begin with $term*\n";
            }
            else {
                my @w = grep {
                            m{\A $term}xms
                            && ! $found{$_}
                        }
                        @words;
                if (@w) {
                    for my $w (@w) {
                        print reveal($w, $nlets, $beg_end), "\n";
                    }
                    $assists += @w;
                    Log "* $cmd $term - $assists\n";
                }
            }
        }
        else {
            print "*illegal reveal command*\n";
        }
    }
    elsif ($word eq 'n') {
        save_state();       # save current puzzle state
        new_puzzle('rand');
    }
    elsif ($word eq 'P') {
        if (! -f "$dir/pangrams.txt") {
            if (we_are_offline()) {
                print "*can't get the words for Pangram Mode when offline*\n";
                next COMMAND;
            }
            `curl -sk $cgi/get_pangrams >$dir/pangrams.txt`;
        }
        PangramMode->play();
    }
    elsif ($word eq 'f') {
        my @dates;
        load_archive();
        if ($last_arch_dt) {
            while (my ($dt, $puz) = each %archive) {
                if (substr($puz, 0, 7) eq $seven) {
                    push @dates, $dt . uc substr($puz, 8, 1);
                }
            }
        }
        else {
            # ask the archive in the cloud
            @dates = `curl -sk $cgi/same_nytbee/$seven`;
            chomp @dates;
        }
        print map {
                  my ($dt, $y, $m, $d, $c) =  m{
                      \A (.. (..)(..)(..))(.) \z 
                  }xms;
                  "$m/$d/$y $c"
                  . ($dt eq $date8? ' *': exists $status{$dt}? ' -': '')
                  . "\n";
              }
              sort @dates;
    }
    elsif ($word eq 'A') {
        if (we_are_offline()) {
            print "*can't get archive when offline*\n";
            next COMMAND;
        }
        my $archive = `curl -sk $cgi/nytbee_archive`;
        open my $out, '>', $arch_fname;
        print {$out} $archive;
        close $out;
        my @archive = split '\n', $archive;
        my $n = @archive;
        printf "Got $n puzzles from %s to %s.\n",
               slash_date($archive[0]),
               slash_date($archive[-1]),
               ;
        %archive = map { substr($_, 0, 8) => substr($_, 9) }
                   @archive;
        if (! -f "$dir/pangrams.txt") {
            my $pangrams = `curl -sk $cgi/get_pangrams`;
            open my $out, '>', "$dir/pangrams.txt";
            print {$out} $pangrams;
            close $out;
        }
    }
    elsif ($word =~ m{\A n \s* (\d{8}) \s* \z}xms) {
        new_puzzle($1);
    }
    elsif (my ($npuz) = $word =~ m{\A n \s* ([1-9]\d*) \s* \z}xms) {
        my @dates = sort keys %status;
        if ($npuz > @dates) {
            print "*not that many puzzles*\n";
            next COMMAND;
        }
        save_state();       # save current puzzle state
        new_puzzle($dates[$npuz-1]);   # -1 since 0 based
    }
    elsif (my ($xpuz) = $word =~ m{\A x \s* (\d+) \s* \z}xms) {
        my @dates = sort keys %status;
        if (@dates == 1) {
            print "*cannot delete the only puzzle*\n";
            next COMMAND;
        }
        if ($xpuz > @dates) {
            print "*not that many puzzles*\n";
            next COMMAND;
        }
        my $dt = $dates[$xpuz-1];

        splice @dates, $xpuz-1, 1;
        delete $status{$dt};

        unlink "$dir/$dt.txt";

        if ($dt eq $date8) {
            new_puzzle($dates[-1], 1);
        }
        show_puzzles('l');
    }
    elsif ($word =~ m{\A n \s* ([0-9/]+) \s* \z}xms) {
        save_state();       # save current puzzle state
        new_puzzle($1);
    }
    elsif ($word eq '!!') {
        # undocumented
        if ($last_shell_command) {
            system($last_shell_command);
        }
    }
    elsif ($word =~ m{\A ! (\S+)}xms) {
        system($1);
        $last_shell_command = $1;
    }
    elsif ($word eq '1') {
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
            my $entry = $entries[ rand @entries ];
            print "$entry\n";
            ++$assists;
            Log "* $entry - $assists\n";
        }
    }
    elsif ($word eq '2') {
        # random non-zero entry in %twolets
        my @entries;
        for my $k (sort keys %twolets) {
            if ($twolets{$k}) {
                push @entries, "\U$k-$twolets{$k}";
            }
        }
        if (@entries) {
            # not Queen Bee yet
            my $entry = $entries[ rand @entries ];
            print "$entry\n";
            ++$assists;
            Log "* $entry - $assists\n";
        }
    }
    elsif (my ($search) = $word =~ m{\A S \s+ (\S+)}xms) {
        if (! -f $arch_fname) {
         print map {
                   slash_date($_) . "\n"
               }
               sort
               `curl -sk $cgi/search_nytbee/$search`
               ;

        }
        else {
            if ($search !~ s{\A -}{}xms) {
                $search = "\\b$search\\b";
            }
            open my $in, '<', $arch_fname;
            while (my $line = <$in>) {
                if ($line =~ m{$search}xms) {
                    print slash_date(substr($line, 0, 8)), "\n";
                }
            }
            close $in;
        }
    }
    elsif ($word eq 'lg' || $word eq 'lga') {
        close $log;     # ensures a full flush
        open my $log_in, '<', $log_fname;
        my $n = 0;
        LINE:
        while (my $line = <$log_in>) {
            if ($line =~ m{\A [*]\s }xms && $word eq 'lg') {
                next LINE;
            }
            ++$n;
            print $line;
            if ($n % 25 == 0) {  # how many?
                print "... ";
                my $ans = <STDIN>; chomp $ans;
                if ($ans eq 'q') {
                    last LINE;
                }
            }
        }
        close $log_in;
        # and reopen
        open $log, '>>', $log_fname;
    }
    #
    # Now we're done with the commands.
    # We have a word.
    #
    elsif ($found{lc $word}) {
        print "*\L$word: already found*\n";
    }
    elsif (length $word < 4) {
        print "*$word: too short*\n";
    }
    elsif (index(lc $word, $center) < 0) {
        print "*$word: does not contain \U$center*\n";
    }
    elsif (! $is_valid_word{lc $word}) {
        print "*$word: not in the word list*\n";
        my %seen;
        for my $c (grep { !$seen{$_}++ } sort split //, $word) {
            if (index($seven, lc $c) < 0) {
                print "*\U$c\E is not one of the seven letters!*\n";
            }
        }
    }
    else {
        # a valid new word
        $word = lc $word;
        my $pg = $is_pangram{$word};
        my $l = length $word;
        $found{$word} = 1;
        push @found, $word;
        Log $word;
        if ($is_pangram{$word}) {
            Log length $word == 7? '**': '*';
        }
        Log "\n";
        --$twolets{substr($word, 0, 2)};
        --$sums{substr($word, 0, 1)}{$l};
        $score += ($l == 4? 1: $l) + ($pg? 7: 0);
        print "$score\n";
        if ($pg) {
            print "PANGRAM!\n";
            $all_pangrams_found = 1;
            PG:
            for my $pg (keys %is_pangram) {
                if (! $found{$pg}) {
                    $all_pangrams_found = 0;
                    last PG;
                }
            }
        }
        if ($score >= $max_points) {
            $rank = 9;
            rank_achieved();
            print "\n";
            show_found(1);
            print "\n" . summary();
            save_state();
        }
        else {
            RANK:
            for my $r ($rank .. $#ranks-1) {
                # note that $#ranks is Queen Bee == 9
                if (   $score >= $ranks[$r]->{value}
                    && $score <  $ranks[$r+1]->{value}
                ) {
                    if ($rank != $r) {
                        $rank = $r;
                        rank_achieved();
                        save_state();
                        last RANK;
                    }
                }
            }
        }
        set_cur_status();
    }
}

{

package PangramMode;

my @pangram_archive;
my $narch;
my $pg_seven;
my @seven;
my $nlets;
my @pangrams;
my %pangrams_found;
my $npangrams;
my $nfound;

sub play {
    system($main::clear);
    print "Pangram Mode\n\n";
    print "Enter h for help\n";
    if (! @pangram_archive) {
        open my $in, '<', "$main::dir/pangrams.txt";
        while (my $line = <$in>) {
            chomp $line;
            push @pangram_archive, $line;
        }
        close $in;
        $narch = @pangram_archive;
    }
    PG:
    while (1) {
        new_word();
        CMD:
        while (1) {
            prompt();
            my $cmd = <STDIN>; chomp $cmd;
            system($main::clear);
            if ($cmd !~ m{\S}xms) {
                next CMD;
            }
            elsif ($cmd eq 'h') {
                print <<'EOH';
h    Show this help
p    Permute the 7 letters
d    Define the pangram(s)
v    Reveal another letter
e    Reveal another beginning and Ending letter
g    Give up and show the pangram(s)
q    Quit and return to Spelling Bee mode
EOH
            }
            elsif ($cmd eq 'q') {
                return;
            }
            elsif ($cmd eq 'g') {
                print "@pangrams\n";
                new_word();
            }
            elsif ($cmd eq 'p') {
                my @new;
                push @new, splice @seven, rand @seven, 1 while @seven;
                @seven = @new;
            }
            elsif ($cmd eq 'v') {
                ++$nlets;
                for my $p (@pangrams) {
                    print main::reveal($p, $nlets, 0), "\n";
                }
            }
            elsif ($cmd eq 'e') {
                ++$nlets;
                for my $p (@pangrams) {
                    print main::reveal($p, $nlets, 1), "\n";
                }
            }
            elsif ($cmd eq 'd') {
                if (main::we_are_offline()) {
                    print "*no definitions when offline*\n";
                    next CMD;
                }
                for my $p (@pangrams) {
                    main::define($p, 0, 1);
                }
            }
            elsif ($cmd =~ m{\A W \s+ (.*)}xms) {
                # undocumented... for testing
                # the words must be correct
                # 7unique word1 word2 ...
                # where wordn has all 7 and only those
                new_word($1);
            }
            else {
                $cmd = lc $cmd;
                for my $c (@seven) {
                    if (index($cmd, lc $c) < 0) {
                        print "*$cmd: does not contain $c*\n";
                        next CMD;
                    }
                }
                for my $c (split //, $cmd) {
                    if (index($pg_seven, $c) < 0) {
                        print "*$cmd: \U$c\E is not in ", @seven, "*\n";
                        next CMD;
                    }
                }
                if ($pangrams_found{$cmd}) {
                    print "*$cmd: already found*\n";
                    next CMD;
                }
                for my $i (0 .. $#pangrams) {
                    if ($cmd eq $pangrams[$i]) {
                        print "yes!\n";
                        ++$nfound;
                        if ($nfound == $npangrams) {
                            next PG;
                        }
                        $pangrams_found{$cmd} = 1;
                        splice @pangrams, $i, 1;    # take it out
                        my $nmore = $npangrams - $nfound;
                        my $verb = $nmore == 1? 'is': 'are';
                        print "there $verb $nmore more\n";
                        next CMD;
                    }
                }
            }
        }
    }
}

sub new_word {
    my $line = shift || $pangram_archive[ rand $narch ];
    ($pg_seven, @pangrams) = split ' ', $line;
    $npangrams = @pangrams;
    %pangrams_found = ();
    $nfound = 0;
    @seven = split //, uc $pg_seven;
    $nlets = 0;
}

sub prompt {
    print "\n";
    print "   $seven[0]   $seven[1]\n";
    print " $seven[2]   $seven[3]   $seven[4]\n";
    print "   $seven[5]   $seven[6]\n\n";
    print "p> ";
}

1;

}   # end package PangramMode
