#!/usr/bin/perl
use strict;
use warnings;

use LWP::Simple qw/
    get
/;
use BeeUtil qw/
    ymd
    get_html
/;

my $bin = '/home4/logical9/www/ultrabee/cgi-bin';
my $bee = '/home4/logical9/www/ultrabee';

use DB_File::Lock;
my %puzzle;
tie %puzzle, 'DB_File::Lock',
             "$bin/nyt_puzzles.dbm",
              O_CREAT|O_RDWR, 0666, $DB_HASH, 'write';
my %definition_of;
tie %definition_of, 'DB_File', 'definition_of.dbm';

# It is now 3:00 a.m. EST.
# Try to get the Spelling Bee words for today.
# If they're not ready yet, sleep 1 second.
#
my ($day, $month, $year) = (localtime())[3 .. 5];
++$month;
$year += 1900;
my $cur_date = sprintf "%4d-%02d-%02d", $year, $month, $day;
my $dt8 = sprintf "%04d%02d%02d", $year, $month, $day;
my $gameData;
SLEEP_LOOP:
while (1) {
    my $html = get "https://www.nytimes.com/puzzles/spelling-bee";
    ($gameData) = $html =~ m! "today": \s* \{ ([^}]*) \} !xms;
        # \s* because there really isn't any space
        # even though Safari shows it
    my ($printDate) = $gameData =~ m{"printDate": \s* "([^"]+)"}xms;
    if ($printDate eq $cur_date) {
        last SLEEP_LOOP;
    }
    sleep 1;
}
my ($words) = $gameData =~ m{"answers":\[ ([^]]*) \]}xms;
my @words = sort $words =~ m{"([^"]*)"}xmsg;
my ($validLetters) = $gameData =~ m{ "validLetters": \s* \[ ([^\]]*) \] }xms;
my $seven = join '', sort $validLetters =~ m{"(.)"}xmsg;
my ($center) = $gameData =~ m{ "centerLetter": \s* "(.)" }xms;

# pangrams and dates a word first appeared
my @pangrams;
my %first_appeared;
use DB_File;
tie %first_appeared, 'DB_File', 'first_appeared.dbm';

WORD:
for my $w (@words) {
    if (! $first_appeared{$w}) {
        $first_appeared{$w} = $dt8;
        # get definition from wordnik.com
        my $html = get_html("https://www.wordnik.com/words/$w");
        my ($def) = $html =~ m{[<]meta\s content='$w:\ ([^']*)'}xms;
        if (! $def) {
            $def = "No definition";
        }
        $def =~ s{[<][^>]*[>]}{}xmsg;
        $def =~ s{[&][#]39;}{'}xmsg;
        $def =~ s{$w}{'*' x length($w)}xmsegi;
        $def =~ s{[^[[:ascii:]]]}{}xmsg;
        eval { $definition_of{$w} = $def; };
            # the above may fail due to wide character??
            # why?  we eliminated non-printable chars!
            # print => ascii - see if it helps
        if ($@) {
            open my $wide, '>>', 'wide.txt';
            print {$wide} "$w: $def\n";
            close $wide;
        }
    }
    if (length $w < 7) {
        next WORD;
    }
    my %seen;
    my @lets = grep { !$seen{$_}++; } split //, $w;
    if (@lets == 7) {
        push @pangrams, $w;
    }
}
untie %first_appeared;

$puzzle{$dt8} = "$seven $center @pangrams | @words";
open my $puzzle_out, '>', 'nyt_puzzles.txt';
for my $dt (sort keys %puzzle) {
    print {$puzzle_out} "$dt => $puzzle{$dt}\n";
}
close $puzzle_out;
untie %puzzle;

# the various lists
system("$bin/nytbee_list.pl");

open my $outlog, '>>', 'beelog/' . ymd();
print {$outlog} "new puzzle for $dt8: @pangrams\n";
close $outlog;


# add the pangrams to nyt_pangrams.html
# they may be there already
#
system "$bin/de_indexize $bee/nyt_pangrams.html";
open my $out, '>>', "$bee/nyt_pangrams.txt";
for my $p (@pangrams) {
    print {$out} "$p\n";
}
close $out;
system "/bin/sort -u -o $bee/nyt_pangrams.txt $bee/nyt_pangrams.txt";
system "$bin/indexize $bee/nyt_pangrams.txt Pangramic Words from the NYT Puzzles";

# now REmake the $bee/goo10k-7-nyt.html file
# thereby ensuring the new pangrams are not there.
#
system "/usr/bin/comm -23 $bee/goo10k-7.txt $bee/nyt_pangrams.txt > $bee/goo10k-7-nyt.txt";
system "$bin/indexize $bee/goo10k-7-nyt.txt Pangramic Words from a list of 10,000 commonly used words";

# and REmake the osx_usd_words-7-nyt-goo.html file
# thereby ensuring the new pangrams are not there either.
#
my $tmp = "/tmp/$$";
system "/bin/cat $bee/nyt_pangrams.txt $bee/goo10k-7-nyt.txt >$tmp;";
system "sort -u -o $tmp $tmp";
system "/usr/bin/comm -23 $bee/osx_usd_words-7.txt $tmp > $bee/osx_usd_words-7-nyt-goo.txt";
system "$bin/indexize $bee/osx_usd_words-7-nyt-goo.txt Pangramic Words from a Large Lexicon";
unlink "$bee/goo10k-7-nyt.txt",
       "$bee/nyt_pangrams.txt",
       "$bee/osx_usd_words-7-nyt-goo.txt",
       $tmp
       ;
# remove the LM time limits
unlink "$bin/end_time_for.dbm";

# add any new words to nyt-words.txt
# and remove them from other-words.txt
# by doing a comm with osx_usd_words-47.txt
#
open my $out2, '>>', "$bin/nyt-words.txt";
for my $w (@words) {
    print {$out2} "$w\n";
}
close $out2;
system "sort -u -o $bin/nyt-words.txt $bin/nyt-words.txt";
system "/usr/bin/comm -23 $bin/osx_usd_words-47.txt $bin/nyt-words.txt >$bin/other-words.txt";

# who played yesterday?
($day, $month, $year) = (localtime(time() - 4*60*60))[3 .. 5];
                                             # 4 hours ago
++$month;
$year += 1900;
$dt8 = sprintf "%04d%02d%02d", $year, $month, $day;
system "$bin/who_played $dt8";
