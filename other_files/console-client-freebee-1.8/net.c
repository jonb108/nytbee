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

#include <curl/curl.h>

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <term.h>
#include <unistd.h>

#include "freebee.h"
#include "version.h"

static void
print_header(void)
{

	putp(clear_screen);

	printf("Free Bee %s | https://freebee.fun/\n\n", VERSION);
	printf("              %c\n", letters[1]);
	printf("          %c       %c\n", letters[0], letters[2]);
	printf("              %c\n", letters[6]);
	printf("          %c       %c\n", letters[3], letters[5]);
	printf("              %c\n\n", letters[4]);
}

void
today(void)
{
	CURL *curl;
	FILE *fp;
	char buf[PATH_MAX];
	int ch, i = 0;

	curl = curl_easy_init();
	if (curl) {
		curl_easy_setopt(curl, CURLOPT_URL, "https://freebee.fun/daily/today.txt");

		/* use a GET to fetch this */
		curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);

		(void) unlink(buf);
		(void) snprintf(buf, sizeof(buf), "%s/today.txt", homedir);
		if ((fp = fopen(buf, "w+")) == NULL)
			return;

		curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
 
		/* Perform the request */
		curl_easy_perform(curl);

		curl_easy_cleanup(curl);

		(void) fseek(fp, 0L, SEEK_SET);
		while ((ch = fgetc(fp)) != EOF) {
			if (i > 6 || !isalpha((unsigned char) ch))
				break;

			letters[i++] = ch;
		}

		(void) fclose(fp);

		(void) unlink(buf);
	}
}

void
yesterday(void)
{
	CURL *curl;
	FILE *fp;
	char buf[PATH_MAX];
	int ch, printed = 8;
	size_t i;

	curl = curl_easy_init();
	if (curl) {
		curl_easy_setopt(curl, CURLOPT_URL, "https://freebee.fun/daily/yesterday.txt");

		/* use a GET to fetch this */
		curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);

		(void) snprintf(buf, sizeof(buf), "%s/yesterday.txt", homedir);
		if ((fp = fopen(buf, "w+")) == NULL)
			return;

		curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
 
		/* Perform the request */
		curl_easy_perform(curl);

		curl_easy_cleanup(curl);

		(void) fseek(fp, 0L, SEEK_SET);

		putp(clear_screen);

		printf("Free Bee %s | https://freebee.fun/\n\n", VERSION);

		/* We need to get the letters separately for UI consistency.  */
		for (i = 0; i < sizeof(letters) - 1; i++) {
			while ((ch = fgetc(fp)) == '\n' || ch == ' ' || ch == '\t' || ch == EOF) {
				if (ch == EOF) {
					puts("Corrupted answer sheet!");
					goto out;
				}
			}

			if (!isalpha((unsigned char) ch)) {
				puts("Corrupted answer sheet!");
				goto out;
			}

			letters[i] = ch;
		}
		i = letters[3];
		letters[3] = letters[6];
		letters[6] = i;

		i = letters[3];
		letters[3] = letters[5];
		letters[5] = i;

		i = letters[3];
		letters[3] = letters[4];
		letters[4] = i;

		if (letters[6] == '\0') {
			puts("Corrupted answer sheet!");
			goto out;
		}

		while ((ch = fgetc(fp)) != EOF) {
			if (ch != '\n' && ch != ' ' && ch != '\t')
				break;
		}

		print_header();

		fputc(ch, stdout);
		while ((ch = fgetc(fp)) != EOF) {
			if (!isprint(ch) && !isblank(ch) && ch != '\n') {
				puts("Corrupted answer sheet!");
				break;
			}

			fputc(ch, stdout);
			if (ch == '\n') {
				if (++printed > rows - 3) {
					while (getchar() != '\n')
						;
					print_header();
					printed = 8;
				}
			}
		}

out:
		(void) memset(letters, 0, sizeof(letters));

		(void) fclose(fp);
		(void) unlink(buf);

		while (getchar() != '\n')
			;

		putp(clear_screen);
	}
}
