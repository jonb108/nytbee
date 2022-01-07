/*
 * Copyright (c) 2020 Brian Callahan <bcallah@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <err.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <term.h>

#include "freebee.h"
#include "version.h"

static void
random_letters(void)
{
	size_t i, j;

	for (i = 0; i < sizeof(letters) - 1; i++) {
bad:
		letters[i] = (unsigned char) arc4random_uniform(26) + 'a';
		for (j = 0; j < i; j++) {
			if (letters[j] == letters[i])
				goto bad;
		}
	}
}

/*
 * Connect to the server and get the daily.
 */
static void
daily_letters(void)
{
	int ch;

	printf("Would you like to see yesterday's answers? (y/n) ");
	ch = getchar();
	while (getchar() != '\n')
		;
	if (ch == 'y' || ch == 'Y')
		yesterday();

	today();
}

/*
 * The seventh letter is the center letter.
 * All valid words must have at least 1 occurance of it.
 */
void
create_anagrams(void)
{
	FILE *fp;
	char *word = NULL;
	int notfirst = 0, pangram;
	int one, two, three, four, five, six;
	size_t i, j, wordsize = 0;
	ssize_t wordlen, special, yes;

	if ((fp = fopen(DICTIONARY, "r")) == NULL)
		err(1, "fopen");

	/*
	 * Start by generating 7 distinct letters.
	 */
	(void) memset(letters, 0, sizeof(letters));
	if (daily == 1) {
		daily_letters();
	} else {
again:
		random_letters();
	}

	if (!notfirst) {
		++notfirst;
		putp(clear_screen);
		printf("Free Bee %s | https://freebee.fun/\n\n", VERSION);
		printf("Creating game, please wait...\n");
	}

	/* Create anagrams.  */
	(void) memset(wordlist, 0, sizeof(wordlist));
	total = 0;
	pangram = 0;
	words = 0;
	while ((wordlen = getline(&word, &wordsize, fp)) != -1) {
		j = 0;
		special = 0;
		yes = 0;
		one = two = three = four = five = six = 0;
		while (word[j] != '\n') {
			for (i = 0; i < 7; i++) {
				if (word[j] == letters[i]) {
					++yes;
					switch (i) {
					case 0:
						one = 1;
						break;
					case 1:
						two = 1;
						break;
					case 2:
						three = 1;
						break;
					case 3:
						four = 1;
						break;
					case 4:
						five = 1;
						break;
					case 5:
						six = 1;
						break;
					case 6:
						special = 1;
					}
					break;
				}
			}
			++j;
		}
		if (special && yes == wordlen - 1) {
			(void) strlcat(wordlist[words], word, sizeof(wordlist[words]));
			++words;
			if (special && one && two && three && four && five && six) {
				pangram = 1;
				total += (strlen(word) - 1) + 7;
			} else {
				if ((i = (strlen(word) - 1)) == 4)
					i = 1;
				total += i;
			}
		}
	}

	/* Not a good game, try again.  */
	if (!pangram || words < 20 || words > 2000) {
		if (daily == 1) {
			printf("Could not create daily game. Creating a random game\n");
			daily = 0;
		}
		(void) fseek(fp, 0L, SEEK_SET);
		goto again;
	}

	free(word);

	(void) fclose(fp);
}
