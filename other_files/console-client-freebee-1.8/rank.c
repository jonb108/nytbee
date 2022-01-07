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

#include <limits.h>
#include <stdio.h>

#include "freebee.h"

const char *
rank(void)
{

	if (points >= queen)
		return "Queen Bee!";
	else if (points >= outstanding)
		return "Outstanding";
	else if (points >= marvellous)
		return "Marvellous";
	else if (points >= superb)
		return "Superb";
	else if (points >= excellent)
		return "Excellent";
	else if (points >= skilled)
		return "Skilled";
	else if (points >= fine)
		return "Fine";
	else if (points >= novice)
		return "Novice";

	return "Newbie";
}

/*
 * I did the math on an NYT game.
 * These were the results.
 */
void
set_rank(void)
{

	novice = total * 0.02;
	fine = total * 0.05;
	skilled = total * 0.08;
	excellent = total * 0.15;
	superb = total * 0.25;
	marvellous = total * 0.40;
	outstanding = total * 0.50;
	queen = total * 0.70;
}
