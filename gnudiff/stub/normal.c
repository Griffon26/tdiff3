/* Normal-format output routines for GNU DIFF.

   Copyright (C) 1988, 1989, 1993, 1995, 1998, 2001 Free Software
   Foundation, Inc.

   This file is part of GNU DIFF.

   GNU DIFF is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   GNU DIFF is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; see the file COPYING.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

#include "diff.h"

typedef void (HunkCallback)(int, int, int, int, void *);

HunkCallback *g_pHunkCallback = NULL;
void *g_pContext = NULL;

void setHunkCallback(HunkCallback *pHunkCallback, void *pContext)
{
  g_pHunkCallback = pHunkCallback;
  g_pContext = pContext;
}

static void print_normal_hunk (struct change *);

/* Print the edit-script SCRIPT as a normal diff.
   INF points to an array of descriptions of the two files.  */

void
print_normal_script (struct change *script)
{
  print_script (script, find_change, print_normal_hunk);
}

/* Print a hunk of a normal diff.
   This is a contiguous portion of a complete edit script,
   describing changes in consecutive lines.  */

static void
print_normal_hunk (struct change *hunk)
{
  lin first0, last0, first1, last1;

  /* Determine range of line numbers involved in each file.  */
  enum changes changes = analyze_hunk (hunk, &first0, &last0, &first1, &last1);
  if (!changes)
    return;

  translate_range(&files[0], first0, last0, &first0, &last0);
  translate_range(&files[1], first1, last1, &first1, &last1);

  g_pHunkCallback(first0, last0, first1, last1, g_pContext);
}
