Free Bee console client
=======================
This is the ncurses-based console client for Free Bee.

What is Free Bee?
-----------------
Free Bee is an enhanced Free Software clone of The New York Times game
Spelling Bee.

In this game, your goal is to find as many words as you can with the seven
letters you are given. You don't have to use any letter except the middle
letter and letters can be used more than once in a word. Finding a word
that uses all seven letters yields bonus points! Every game has at least
one such word, and many games have multiple.

Earning enough points to reach the rank of Queen Bee wins the game!

You can play the daily challenge like the original game or try your hand at a
nearly infinite number of computer-generated random challenges. Unlike the
original game, you are not restricted to only a single game per day!

The only notable difference between Free Bee and the original game is the use
 of the ENABLE dictionary instead of the NYT dictionary. Patches welcome.

Find us on the web at https://freebee.fun/

Dependencies
------------
Free Bee depends on `ncurses` for some screen handling routines and `libcurl`
for network routines. Both should be easily installable on your operating
system.

Compiling
---------
Just run `make`. Development of Free Bee is done on OpenBSD and I'm using
some OpenBSD extensions. Please edit the
`CFLAGS += -DHAVE_ARC4RANDOM_UNIFORM -DHAVE_STRLCAT` and the
`CFLAGS += -DHAVE_PLEDGE -DHAVE_UNVEIL` lines in the `Makefile`
to reflect whether or not your system has those extensions or needs the
portable versions included in this repository.

License
-------
ISC License. See `LICENSE` for details.

The ENABLE dictionary is Public Domain.
