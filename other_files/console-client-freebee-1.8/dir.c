
:/*
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

#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "freebee.h"

void
create_dir(void)
{
	mode_t mode;

	mode = 0777 & ~umask(0);
	if (getenv("HOME") == NULL)
		snprintf(homedir, sizeof(homedir), "./");
	else
		snprintf(homedir, sizeof(homedir), "%s/.freebee", getenv("HOME"));

#ifdef HAVE_UNVEIL
	if (!unveiled) {
		if (unveil(homedir, "rwc") == -1)
			err(1, "unveil");
		if (unveil(CERT, "r") == -1)
			err(1, "unveil");
		if (unveil(DICTIONARY, "rx") == -1)
			err(1, "unveil");
		if (unveil(NULL, NULL) != 0)
			err(1, "unveil");
		unveiled = 1;
	}
#endif /* HAVE_UNVEIL */

	if (mkdir(homedir, mode) == -1) {
		if (errno != EEXIST)
			err(1, "mkdir");
	}
}
