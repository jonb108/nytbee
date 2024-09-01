use DB_File;
my %osx_usd_words_48;
tie %osx_usd_words_48, 'DB_File', 'osx_usd_words-48.dbm';
open my $in, '<', 'osx_usd_words-48.txt';
while (my $word = <$in>) {
    chomp $word;
    $osx_usd_words_48{$word} = 1;
}
