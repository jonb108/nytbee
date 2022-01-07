# the main script
nytbee.pl

# creation of a community puzzle:
../mk_puz.html - Step 1 which gets a pangramic word
                     referencing ../pangrams.txt
                                 ../comm_not_puz.txt     
                                 ../lbig.txt
                     then calls mkpuz_tally
mkpuz_tally    - Step 2 which calculates and ddisplays tables of tallies
                     and then calls gwords when center letter is chosen
gwords         - Step 3 - displays lists of qualified words
                     references pwords.txt
                            and fourminus.txt
pwords.txt     - all words ever used in the NYT bee puzzles
                     as of 12/31/21 
fourminus.txt  - the big lexicon of words of length >= 4
                     minus the pwords.txt words
clues          - Step 4 - gets the chosen words and asks for clues
                     and then calls get_clues
get_clues      - Step 5 gets the clues and presents a form
                     for puzzle and maker info
final_mkpuz    - gets the info and creates the community puzzle
                     references community_puzzles/last_num.txt

# for the command line to call:
get_nytbee     - scrape the nytimes.com/puzzles/spelling-bee site
                     for today's 7 letters and word list
cron_jon       - the crontab file to call get_nytbee at 3:00 EST
get_pangrams   - returns pangrams.txt for pangram mode in command mode
                     references cmd_pangrams.txt
pangrams.txt   - used by get_pangrams
load_nytbee    - read nytbee.txt and write the .dbm file
nytbee.txt     - the archive from 5/29/18 to 12/22/21
nytbee         - return the puzzle for a given date
nytbee_archive - return the entire archive file from the .dbm file
rand_nytbee    - a random puzzle from the archive
same_nytbee    - search the archive for same 7 letters
search_nytbee  - search the archive for the word
tally_nytbee   - tally up the puzzles - longest/fewest etc
                     for creating the Archive section
