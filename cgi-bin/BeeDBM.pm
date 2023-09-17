use strict;
use warnings;
package BeeDBM;

use base 'Exporter';
our @EXPORT_OK = qw/
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
    %full_uuid
    %added_words
/;

use DB_File;
use DB_File::Lock;

our %end_time_for;
tie %end_time_for, 'DB_File', 'end_time_for.dbm';
# key is the uuid ("session" id)
# value is # of minutes past midnight
# after which THEY decided they don't want
# to play any more.

our %uuid_ip;
tie %uuid_ip, 'DB_File', 'uuid_ip.dbm';
# key: uid, value: ip address 
# so we can know where people are playing from

our (%uuid_screen_name, %screen_name_uuid);
tie %uuid_screen_name, 'DB_File', 'uuid_screen_name.dbm';
tie %screen_name_uuid, 'DB_File', 'screen_name_uuid.dbm';
#
# a 'screen name' for privacy - rather than using
# the ip address to derive location - country/state/city.
#
# two dbm files
# uuid_screen_name - key uuid11 value screen_name
# screen_name_uuid - key screen_name value uuid11

our %num_msgs;
tie %num_msgs, 'DB_File', 'num_msgs.dbm';
# how many msgs in the forum for the puzzle?

our %puzzle;
tie %puzzle, 'DB_File', 'nyt_puzzles.dbm';
# the NYT archive
# key is d8
# value is seven center pangrams... | words

our %cur_puzzles_store;
tie %cur_puzzles_store, 'DB_File::Lock', 'cur_puzzles_store.dbm',
                        O_CREAT|O_RDWR, 0666, $DB_HASH, 'write';
# a better way of storing the current puzzle list for *everyone*
# key is the uuid ("session" id)
# value is a Data::Dumper created *string* representing a hash
#     whose keys are the $date (or cp#)
#     and the value is 6 numbers followed by words:
#     0 #hints
#     1 all_pangrams_found
#     2 ht_chosen
#     3 tl_chosen
#     4 rank 
#     5 score_at_first_hint
#     words_found...

our %puzzle_has_clues;
tie %puzzle_has_clues, 'DB_File', 'nyt_puzzle_has_clues.dbm';
# clues for NYT puzzles are stored in the mysql database
# we want to avoid getting a connection each time just to
# see if there are any clues so ...
# key is puzzle_date
# value is does the puzzle have any clues? - always 1
# i.e. if the puzzle key is there then the puzzle has clues
# you can ask 'exists' if you'd like

our %osx_usd_words_47;
tie %osx_usd_words_47, 'DB_File', 'osx_usd_words-47.dbm';
# this is the large lexicon from OSX
# it was purged of words of length < 4, proper names,
# and words with more than 7 unique letters.
# /usr/share/dict/words has 235,886 words
# osx_usd_words-47.txt has 98,634 words
# key is the word, value is just 1
# we use this hash to check for donut words
# and for 'missing' words.

our %osx_usd_words_48;
tie %osx_usd_words_48, 'DB_File', 'osx_usd_words-48.dbm';
# this is the large lexicon from OSX
# it was purged of words of length < 4, proper names,
# and words with more than 8 unique letters.
# /usr/share/dict/words has 235,886 words
# osx_usd_words-48.txt has 140,194 words
# key is the word, value is just 1
# we use this hash to check for bonus words

our %added_words;
tie %added_words, 'DB_File', 'added_words.dbm';
# key is the word, value is just 1
# we use this hash to check for missing donut and bonus words
# that were added because they weren't in the large
# lexicon or in the nytbee.

our %first_appeared;
tie %first_appeared, 'DB_File', 'first_appeared.dbm';
# a hash with keys of all words that ever
# appeared in an NYT puzzle.   value is the date (yyyymmdd)
# of first appearance.

our %definition_of;
tie %definition_of, 'DB_File', 'definition_of.dbm';
# a hash with keys of the words in the NYTBee
# value is a simple definition from worknik.com

our %message_for;
tie %message_for, 'DB_File', 'message_for.dbm';
# key is the uuid ("session" id)
# value is "# date 1/0"
# the number of the last message (in directory message/)
# the user saw and the date they saw it
# the last number is for status = 1 is graphical, 0 is numeric

our %uuid_colors_for;
tie %uuid_colors_for, 'DB_File', 'uuid_colors_for.dbm';
# key is uuid
# value is a Data::Dumper created *string* representing a hash
#     whose keys are:
#       center_hex center_text
#       donut_hex donut_text
#       background letter link
#     and whose values are colors in one of these forms:
#       either html_name, #FFa9e4, rgb(114, 100, 29A), hsl(34, 50%, 20%)

our %full_uuid;
tie %full_uuid, 'DB_File', 'full_uuid.dbm';
# key is uuid11
# value is the full uuid
# This is needed because I thought the full uuid was just too long
# and unnecessarly so.  Premature optimization...

1;
