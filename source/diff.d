/*
 * tdiff3 - a text-based 3-way diff/merge tool that can handle large files
 * Copyright (C) 2014  Maurice van der Pot <griffon26@kfk4ever.com>
 * Copyright (C) 2014  Joachim Eibl <joachim.eibl at gmx.de>
 *
 * This file is part of tdiff3.
 *
 * tdiff3 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * tdiff3 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with tdiff3; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

/**
 * This module contains the alignment algorithm taken from KDiff3.
 *
 * Authors: Maurice van der Pot, Joachim Eibl
 * License: $(LINK2 http://www.gnu.org/licenses/gpl-2.0.txt, GNU GPL v2.0) or later.
 */
module diff;

import std.algorithm;
import std.array;
import std.c.locale;
import std.container;
import std.conv;
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.typecons;
import std.utf;

import common;
import ilineprovider;
import myassert;
import unittestdata;

void printDiff3List(Diff3LineList d3ll,
                    shared ILineProvider lpA,
                    shared ILineProvider lpB,
                    shared ILineProvider lpC)
{
    const int columnsize = 30;
    const int linenumsize = 6;
    foreach(d3l; d3ll)
    {
        string lineAText, lineBText, lineCText;
        if(d3l.lineA != -1)
        {
            lineAText = format("%6.6d %-30.30s", d3l.lineA, lpA.get(d3l.lineA).get().replace("\n", "\\n"));
        }
        else
        {
            lineAText = format("%37s", "");
        }
        if(d3l.lineB != -1)
        {
            lineBText = format("%6.6d %-30.30s", d3l.lineB, lpB.get(d3l.lineB).get().replace("\n", "\\n"));
        }
        else
        {
            lineBText = format("%37s", "");
        }
        if(d3l.lineC != -1)
        {
            lineCText = format("%6.6d %-30.30s", d3l.lineC, lpC.get(d3l.lineC).get().replace("\n", "\\n"));
        }
        else
        {
            lineCText = format("%37s", "");
        }
        writefln("%s %s %s %s %s %s", lineAText, lineBText, lineCText, d3l.bAEqB, d3l.bAEqC, d3l.bBEqC);
    }
}

void validateDiff3LineListForN(Diff3LineList diff3LineList, int n, int leftLine, int rightLine)
{
    int line = leftLine;
    foreach(d3l; diff3LineList)
    {
        if(d3l.line(n) == -1)
            continue;

        assertEqual(line, d3l.line(n));
        line++;
    }
    assertEqual(line, rightLine + 1);
}

private void updateDiff3LineListUsingAB(DiffList diffList12, ref Diff3LineList diff3LineList)
{
    int lineA = 0;
    int lineB = 0;

    foreach(d; diffList12)
    {
        while(d.nofEquals > 0)
        {
            Diff3Line d3l = Diff3Line.init;
            d3l.bAEqB = true;
            d3l.lineA = lineA++;
            d3l.lineB = lineB++;
            diff3LineList.insertBack(d3l);
            d.nofEquals--;
        }
        while(d.diff1 > 0 && d.diff2 > 0)
        {
            Diff3Line d3l = Diff3Line.init;
            d3l.lineA = lineA++;
            d3l.lineB = lineB++;
            diff3LineList.insertBack(d3l);
            d.diff1--;
            d.diff2--;
        }
        while(d.diff1 > 0)
        {
            Diff3Line d3l = Diff3Line.init;
            d3l.lineA = lineA++;
            diff3LineList.insertBack(d3l);
            d.diff1--;
        }
        while(d.diff2 > 0)
        {
            Diff3Line d3l = Diff3Line.init;
            d3l.lineB = lineB++;
            diff3LineList.insertBack(d3l);
            d.diff2--;
        }
    }

    /* Post condition:
     * - Diff3Line entries only have lineA/lineB set
     * - per Diff in the difflist:
     *   First equal lines in A and B come side by side
     *   then differing lines in A and B come side by side
     *   then the remaining lines in either A or B
     */
}

private Tuple!(bool, bool, bool, int, int, int) toTuple(Diff3Line d3l)
{
    return tuple(d3l.bAEqB, d3l.bAEqC, d3l.bBEqC, d3l.lineA, d3l.lineB, d3l.lineC);
}

private Diff3Line fromTuple(Tuple!(bool, bool, bool, int, int, int) t)
{
    Diff3Line d3l;
    d3l.bAEqB = t[0];
    d3l.bAEqC = t[1];
    d3l.bBEqC = t[2];
    d3l.lineA = t[3];
    d3l.lineB = t[4];
    d3l.lineC = t[5];
    return d3l;
}

private Tuple!(bool, bool, bool, int, int, int)[] toTuples(Diff3LineList d3ll)
{
    Tuple!(bool, bool, bool, int, int, int)[] d3ltuples;
    foreach(d3l; d3ll)
    {
        d3ltuples ~= toTuple(d3l);
    }

    return d3ltuples;
}

private Diff3LineList toDiff3LineList(Tuple!(bool,bool,bool,int,int,int)[] d3ltuples)
{
    Diff3LineList d3ll;
    foreach(t; d3ltuples)
    {
        d3ll.insertBack(fromTuple(t));
    }
    return d3ll;
}

unittest
{
    Diff3LineList d3ll;
    DiffList dl = [Diff(1,0,0)];

    updateDiff3LineListUsingAB(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(true, false, false, 0, 0, -1));
    assertEqual(d3ltuples.length, 1);
}

unittest
{
    Diff3LineList d3ll;
    DiffList dl = [Diff(0,1,0)];

    updateDiff3LineListUsingAB(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, 0, -1, -1));
    assertEqual(d3ltuples.length, 1);
}

unittest
{
    Diff3LineList d3ll;
    DiffList dl = [Diff(0,0,1)];

    updateDiff3LineListUsingAB(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1, 0, -1));
    assertEqual(d3ltuples.length, 1);
}

unittest
{
    Diff3LineList d3ll;
    DiffList dl = [Diff(0,1,1)];

    updateDiff3LineListUsingAB(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, 0, 0, -1));
    assertEqual(d3ltuples.length, 1);
}

unittest
{
    Diff3LineList d3ll;
    DiffList dl = [Diff(1,1,2)];

    updateDiff3LineListUsingAB(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(true, false, false, 0, 0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false, 1, 1, -1));
    assertEqual(d3ltuples[2], tuple(false, false, false, -1, 2, -1));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    Diff3LineList d3ll;
    DiffList dl = [Diff(1,1,2), Diff(1,0,0)];

    updateDiff3LineListUsingAB(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(true, false, false, 0, 0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false, 1, 1, -1));
    assertEqual(d3ltuples[2], tuple(false, false, false, -1, 2, -1));
    assertEqual(d3ltuples[3], tuple(true, false, false, 2, 3, -1));
    assertEqual(d3ltuples.length, 4);
}

private void updateDiff3LineListUsingAC(DiffList diffList13, ref Diff3LineList diff3LineList)
{
    int lineA = 0;
    int lineC = 0;

    auto r3 = diff3LineList[];

    foreach(d; diffList13)
    {
        while(d.nofEquals > 0)
        {
            while(r3.front().lineA != lineA)
            {
                r3.popFront();
            }

            r3.front().lineC = lineC;
            r3.front().bAEqC = true;
            r3.front().bBEqC = r3.front().bAEqB;

            d.nofEquals--;
            lineA++;
            lineC++;
            r3.popFront();
        }
        while(d.diff1 > 0)
        {
            d.diff1--;
            lineA++;
        }
        while(d.diff2 > 0)
        {
            Diff3Line d3l = Diff3Line.init;
            d3l.lineC = lineC;
            diff3LineList.insertBefore(r3, d3l);
            d.diff2--;
            lineC++;
        }
    }

    /* Post condition:
     * - per Diff in the difflist:
     *   - First equal lines from C added next to their counterpart in A
     *   - then differing lines from C are inserted immediately after the above
     *
     *  A Be Ce
     *  A Be Ce
     *       Cd
     *       Cd
     *  A Be
     *  A Bd
     *    Bd
     *
     */
}

unittest
{
    /* Add two equal lines in C and check if equality is set correctly for A and B */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false, 0, 0, -1),
                                          tuple(true,  false, false, 1, 1, -1)]);
    DiffList dl = [Diff(2,0,0)];

    updateDiff3LineListUsingAC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, true, false, 0, 0, 0));
    assertEqual(d3ltuples[1], tuple(true,  true, true , 1, 1, 1));
    assertEqual(d3ltuples.length, 2);
}

unittest
{
    /* Check if equal lines are inserted at the right offset if lines from A
     * don't start at the beginning of the list */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false,  0, -1, -1)
                                          ]);
    DiffList dl = [Diff(1,0,0)];

    updateDiff3LineListUsingAC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1, -1, -1));
    assertEqual(d3ltuples[1], tuple(false, true,  false,  0, -1,  0));
    assertEqual(d3ltuples.length, 2);
}

unittest
{
    /* Check if the right number of lines is skipped for a difference with A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, -1, -1),
                                          tuple(false, false, false,  1, -1, -1),
                                          tuple(false, false, false,  2, -1, -1)
                                          ]);
    DiffList dl = [Diff(0,2,0),
                   Diff(1,0,0)];

    updateDiff3LineListUsingAC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  0, -1, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false,  1, -1, -1));
    assertEqual(d3ltuples[2], tuple(false, true,  false,  2, -1,  0));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    /* Check if differing lines in C are inserted before the existing list,
     * shifting both A and B and if the next equal line is still inserted
     * at the expected position */
    Diff3LineList d3ll = toDiff3LineList([tuple(true, false, false,  0, 1, -1),
                                          ]);
    DiffList dl = [Diff(0,0,2),
                   Diff(1,0,0)];

    updateDiff3LineListUsingAC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1, -1,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1, -1,  1));
    assertEqual(d3ltuples[2], tuple(true,  true,  true,   0,  1,  2));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    /* Check if differing lines in C are inserted before the existing list,
     * shifting both A and B and if the next equal line is still inserted
     * at the expected position if there are also differing lines in A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, 0, -1),
                                          tuple(false, false, false,  1, 1, -1)
                                          ]);
    DiffList dl = [Diff(0,1,1),
                   Diff(1,0,0)];

    updateDiff3LineListUsingAC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1, -1,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false,  0,  0, -1));
    assertEqual(d3ltuples[2], tuple(false, true,  false,  1,  1,  1));
    assertEqual(d3ltuples.length, 3);
}

private void moveLowerLineUp(Diff3LineList diff3LineList,
                             Diff3LineList.Range r3b,
                             Diff3LineList.Range r3c)
{
    // Is it possible to move this line up?
    // Test if no other B's are used between r3c and r3b

    // First test which is before: r3c or r3b ?
    /* TODO: isn't there a better way to compare ranges? */
    auto r3b1 = r3b;
    auto r3c1 = r3c;
    while(r3b1 != r3c && r3c1 != r3b)
    {
        assert(!r3b1.empty() || !r3c1.empty());
        if(!r3b1.empty) r3b1.popFront();
        if(!r3c1.empty) r3c1.popFront();
    }


    /* The code below works for B before C as well as C before B, but to avoid
     * having to write more or less the same code twice it uses some locally
     * defined functions to access things like bAEqB/bAEqC/lineB/lineC.
     *
     * The locally defined functions are named left* and right*. When reading
     * the code just assume that the line on the left is above the line on the
     * right. The functions take care of swapping everything when it's the
     * other way around.
     */

    bool b_first = (r3b1 == r3c);

    ref bool leftEqualToA(ref Diff3Line d3l) { return b_first ? d3l.bAEqB : d3l.bAEqC; }
    ref bool rightEqualToA(ref Diff3Line d3l) { return b_first ? d3l.bAEqC : d3l.bAEqB; }
    ref bool leftEqualToRight(ref Diff3Line d3l) { return d3l.bBEqC; }
    ref int leftLine(ref Diff3Line d3l) { return b_first ? d3l.lineB : d3l.lineC; }
    ref int rightLine(ref Diff3Line d3l) { return b_first ? d3l.lineC : d3l.lineB; }

    Diff3LineList.Range first = b_first ? r3b : r3c;
    Diff3LineList.Range last = b_first ? r3c : r3b;

    if(!rightEqualToA(last.front)) // left before right
    {
        auto r3 = first;

        auto r3_last_equal_A = last;
        int nofDisturbingLines = 0;

        while(r3 != last)
        {
            assert(!r3.empty());
            if(rightLine(r3.front) != -1)
            {
                nofDisturbingLines++;

                if(rightEqualToA(r3.front))
                {
                    r3_last_equal_A = r3;
                }
            }
            r3.popFront();
        }

        if(nofDisturbingLines > 0)
        {
            /* If i3_last_equal_A isn't still set to d3ll.end(), then
             * we've found a line in A that is equal to one in C
             * somewhere between i3b and i3c
             */
            bool before_or_on_equal_line_in_A = (r3_last_equal_A != last);

            r3 = first;
            while(r3 != last)
            {
                if( (rightLine(r3.front) != -1) ||
                    (before_or_on_equal_line_in_A && r3.front.lineA != -1) )
                {
                    Diff3Line d3l;
                    rightLine(d3l) = rightLine(r3.front);
                    rightLine(r3.front) = -1;

                    if(before_or_on_equal_line_in_A)
                    {
                        d3l.lineA = r3.front.lineA;
                        rightEqualToA(d3l) = rightEqualToA(r3.front);
                        r3.front.lineA = -1;
                        leftEqualToA(r3.front) = false;
                    }

                    rightEqualToA(r3.front) = false;
                    leftEqualToRight(r3.front) = false;
                    diff3LineList.insertBefore(first, d3l);
                }

                if(r3 == r3_last_equal_A)
                {
                    before_or_on_equal_line_in_A = false;
                }

                r3.popFront();
            }
            nofDisturbingLines = 0;
        }

        assert(nofDisturbingLines == 0);
        rightLine(first.front) = rightLine(last.front);
        leftEqualToRight(first.front) = true;
        rightEqualToA(first.front) = leftEqualToA(first.front);
        rightLine(last.front) = -1;
        rightEqualToA(last.front) = false;
        leftEqualToRight(last.front) = false;
    }
}

version(unittest)
auto rangeFrom(Diff3LineList d3ll, int index)
{
    auto range = d3ll[];
    while(index--)
    {
        range.popFront();
    }
    return range;
}

unittest
{
    /* Move up an unobstructed B */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, -1, 0),
                                          tuple(false, false, false,  1, -1, 1),
                                          tuple(false, false, false,  2,  0, 2),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 2), rangeFrom(d3ll, 0));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, true,   0,  0,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false,  1, -1,  1));
    assertEqual(d3ltuples[2], tuple(false, false, false,  2, -1,  2));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    /* Don't move up an unobstructed B if it is equal to A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, -1, 0),
                                          tuple(false, false, false,  1, -1, 1),
                                          tuple(true,  false, false,  2,  0, 2),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 2), rangeFrom(d3ll, 0));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  0, -1,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false,  1, -1,  1));
    assertEqual(d3ltuples[2], tuple(true,  false, false,  2,  0,  2));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    /* Move up a line in B obstructed by a line that is *not* equal to A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, -1, 0),
                                          tuple(false, false, false,  1, -1, 1),
                                          tuple(false, false, false,  2,  0, 2),
                                          tuple(false, false, false,  3,  1, 3),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 3), rangeFrom(d3ll, 1));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  0, -1,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1,  0, -1));
    assertEqual(d3ltuples[2], tuple(false, false, true,   1,  1,  1));
    assertEqual(d3ltuples[3], tuple(false, false, false,  2, -1,  2));
    assertEqual(d3ltuples[4], tuple(false, false, false,  3, -1,  3));
    assertEqual(d3ltuples.length, 5);
}

unittest
{
    /* Move up a line in B obstructed by a line that is equal to A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  2, -1,  4),
                                          tuple(false, false, false,  3, -1,  5),
                                          tuple(true,  false, false,  4,  4,  6),
                                          tuple(false, false, false,  5,  5,  7),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 3), rangeFrom(d3ll, 1));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  2, -1,  4));
    assertEqual(d3ltuples[1], tuple(false, false, false,  3, -1, -1));
    assertEqual(d3ltuples[2], tuple(true,  false, false,  4,  4, -1));
    assertEqual(d3ltuples[3], tuple(false, false, true,  -1,  5,  5));
    assertEqual(d3ltuples[4], tuple(false, false, false, -1, -1,  6));
    assertEqual(d3ltuples[5], tuple(false, false, false,  5, -1,  7));
    assertEqual(d3ltuples.length, 6);
}

unittest
{
    /* Move up an unobstructed C */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, 0, -1),
                                          tuple(false, false, false,  1, 1, -1),
                                          tuple(false, false, false,  2, 2,  0),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 0), rangeFrom(d3ll, 2));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, true,   0,  0,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false,  1,  1, -1));
    assertEqual(d3ltuples[2], tuple(false, false, false,  2,  2, -1));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    /* Don't move up an unobstructed C if it is equal to A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, 0, -1),
                                          tuple(false, false, false,  1, 1, -1),
                                          tuple(false, true,  false,  2, 2,  0),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 0), rangeFrom(d3ll, 2));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  0,  0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false,  1,  1, -1));
    assertEqual(d3ltuples[2], tuple(false, true,  false,  2,  2,  0));
    assertEqual(d3ltuples.length, 3);
}

unittest
{
    /* Move up a line in C obstructed by a line that is *not* equal to A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  0, 0, -1),
                                          tuple(false, false, false,  1, 1, -1),
                                          tuple(false, false, false,  2, 2,  0),
                                          tuple(false, false, false,  3, 3,  1),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 1), rangeFrom(d3ll, 3));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  0,  0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1, -1,  0));
    assertEqual(d3ltuples[2], tuple(false, false, true,   1,  1,  1));
    assertEqual(d3ltuples[3], tuple(false, false, false,  2,  2, -1));
    assertEqual(d3ltuples[4], tuple(false, false, false,  3,  3, -1));
    assertEqual(d3ltuples.length, 5);
}

unittest
{
    /* Move up a line in C obstructed by a line that is equal to A */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  2,  4, -1),
                                          tuple(false, false, false,  3,  5, -1),
                                          tuple(false, true,  false,  4,  6,  4),
                                          tuple(false, false, false,  5,  7,  5),
                                          ]);

    moveLowerLineUp(d3ll, rangeFrom(d3ll, 1), rangeFrom(d3ll, 3));

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  2,  4, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false,  3, -1, -1));
    assertEqual(d3ltuples[2], tuple(false, true,  false,  4, -1,  4));
    assertEqual(d3ltuples[3], tuple(false, false, true,  -1,  5,  5));
    assertEqual(d3ltuples[4], tuple(false, false, false, -1,  6, -1));
    assertEqual(d3ltuples[5], tuple(false, false, false,  5,  7, -1));
    assertEqual(d3ltuples.length, 6);
}


private void updateDiff3LineListUsingBC(DiffList diffList23, ref Diff3LineList diff3LineList)
{

    int lineB = 0;
    int lineC = 0;

    auto r3b = diff3LineList[];
    auto r3c = diff3LineList[];

    foreach(d; diffList23)
    {
        while(d.nofEquals > 0)
        {
            while(r3b.front().lineB != lineB)
            {
                r3b.popFront();
            }
            while(r3c.front().lineC != lineC)
            {
                r3c.popFront();
            }

            assert(!r3b.empty());
            assert(!r3c.empty());

            if(r3b == r3c)
            {
                assertEqual(r3b.front().lineC, lineC);
                r3b.front().bBEqC = true;
            }
            else
            {
                moveLowerLineUp(diff3LineList, r3b, r3c);
            }

            d.nofEquals--;
            lineB++;
            lineC++;
            r3b.popFront();
            r3c.popFront();
        }

        auto r3from = r3b;
        while(d.diff1 > 0)
        {
            /* Move lines in B that are not equal to A or C as far up as they
             * can, i.e. insert it between the previous line from B and the
             * lines from A and C that follow it
             */
            while(r3from.front.lineB != lineB)
            {
                assert(r3from.front.lineB == -1);
                r3from.popFront();
            }
            if(r3from != r3b && !r3from.front.bAEqB)
            {
                Diff3Line d3l;
                d3l.lineB = lineB;
                diff3LineList.insertBefore(r3b, d3l);
                r3from.front.lineB = -1;
            }
            else
            {
                r3from.popFront();
                r3b = r3from;
            }
            d.diff1--;
            lineB++;
        }

        while(d.diff2 > 0)
        {
            d.diff2--;
            lineC++;
        }
    }
}

unittest
{
    /* Test for while(d.diff1 > 0)
     * Check that nothing is done if lineB is already at the beginning */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  4,  0, -1),
                                          tuple(false, false, false,  5,  1, -1)
                                          ]);
    DiffList dl = [Diff(0,2,0)];

    updateDiff3LineListUsingBC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  4,  0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false,  5,  1, -1));
    assertEqual(d3ltuples.length, 2);
}

unittest
{
    /* Test for while(d.diff1 > 0)
     * Check that B is moved up if it is not at the beginning */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  4, -1,  7),
                                          tuple(false, false, false,  5,  0,  8),
                                          tuple(false, false, false,  6,  1,  9)
                                          ]);
    DiffList dl = [Diff(0,2,0)];

    updateDiff3LineListUsingBC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1,  0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1,  1, -1));
    assertEqual(d3ltuples[2], tuple(false, false, false,  4, -1,  7));
    assertEqual(d3ltuples[3], tuple(false, false, false,  5, -1,  8));
    assertEqual(d3ltuples[4], tuple(false, false, false,  6, -1,  9));
    assertEqual(d3ltuples.length, 5);
}

unittest
{
    /* Test for while(d.diff1 > 0)
     * Check that B (line 2) is moved up enough to make room for an equal C (line 0) */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  4, -1,  0),
                                          tuple(false, false, false,  5,  0,  1),
                                          tuple(false, false, false,  6,  1,  2),
                                          tuple(false, false, false,  7,  2,  3)
                                          ]);
    DiffList dl = [Diff(0,2,0),
                   Diff(1,0,0)];

    updateDiff3LineListUsingBC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1,  0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1,  1, -1));
    assertEqual(d3ltuples[2], tuple(false, false, true,   4,  2,  0));
    assertEqual(d3ltuples[3], tuple(false, false, false,  5, -1,  1));
    assertEqual(d3ltuples[4], tuple(false, false, false,  6, -1,  2));
    assertEqual(d3ltuples[5], tuple(false, false, false,  7, -1,  3));
    assertEqual(d3ltuples.length, 6);
}

unittest
{
/*
difflist23: [Diff(2, 1, 1), Diff(1, 2, 17), Diff(32, 0, 0)]

000000 /* -*- Mode: C; tab-width: 8;  000000 /* -*- Mode: C; tab-width: 8;  000000 /* -*- Mode: C; tab-width: 8;  true true true
000001 /*\n                           000001 /*\n                           000001 /*\n                           true true true
000002  * Copyright (C) 2002 CodeFact 000002  * Copyright (A) 2002 CodeFact 000002  * Copyright (C) 2002 CodeFact false true false
                                                                            000003  * Copyright (C) 2002 Richard  false false false
                                                                            000004  * Copyright (A) 2002 Mikael H false false false
000003  * Copyright (A) 2002 Richard  000003  * Copyright (C) 2002 Richard                                        false false false
000004  * Copyright (C) 2002 Mikael H 000004  * Copyright (C) 2002 Mikael H                                       true false false
000005  * Copyright (A) 2004 Alvaro d 000005  * Copyright (C) 2004 Alvaro d 000005  * Copyright (A) 2004 Alvaro d false true false
*/

    Diff3LineList d3ll = toDiff3LineList([tuple(true,  true,  true,   0,  0,  0),
                                          tuple(true,  true,  true,   1,  1,  1),
                                          tuple(false, true,  false,  2,  2,  2),
                                          tuple(false, false, false, -1, -1,  3),
                                          tuple(false, false, false, -1, -1,  4),
                                          tuple(false, false, false,  3,  3, -1),
                                          tuple(true,  false, false,  4,  4, -1),
                                          tuple(false, true,  false,  5,  5,  5),
                                          ]);
    DiffList dl = [Diff(2,1,1),
                   Diff(1,2,2)];

    writefln("------------------------------------------");
    updateDiff3LineListUsingBC(dl, d3ll);
    writefln("------------------------------------------");


/*
000000 /* -*- Mode: C; tab-width: 8;  000000 /* -*- Mode: C; tab-width: 8;  000000 /* -*- Mode: C; tab-width: 8;  true true true
000001 /*\n                           000001 /*\n                           000001 /*\n                           true true true
000002  * Copyright (C) 2002 CodeFact                                       000002  * Copyright (C) 2002 CodeFact false true false
                                      000002  * Copyright (A) 2002 CodeFact 000003  * Copyright (C) 2002 Richard  false false true
                                      000003  * Copyright (C) 2002 Richard                                        false false false
                                                                            000004  * Copyright (A) 2002 Mikael H false false false
000003  * Copyright (A) 2002 Richard                                                                              false false false
000004  * Copyright (C) 2002 Mikael H 000004  * Copyright (C) 2002 Mikael H                                       true false false
000005  * Copyright (A) 2004 Alvaro d 000005  * Copyright (C) 2004 Alvaro d 000005  * Copyright (A) 2004 Alvaro d false true false

*/

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(true,  true,  true,   0,  0,  0));
    assertEqual(d3ltuples[1], tuple(true,  true,  true,   1,  1,  1));
    assertEqual(d3ltuples[2], tuple(false, true,  false,  2,  2,  2));
    assertEqual(d3ltuples[3], tuple(false, false, true,  -1,  3,  3));
    assertEqual(d3ltuples[4], tuple(false, false, false, -1, -1,  4));
    assertEqual(d3ltuples[5], tuple(false, false, false,  3, -1, -1));
    assertEqual(d3ltuples[6], tuple(true,  false, false,  4,  4, -1));
    assertEqual(d3ltuples[7], tuple(false, true,  false,  5,  5,  5));
    assertEqual(d3ltuples.length, 8);

}

Diff3LineList calcDiff3LineList(DiffList diffList12, DiffList diffList13, DiffList diffList23)
{
    Diff3LineList diff3LineList;

    updateDiff3LineListUsingAB(diffList12, diff3LineList);
    updateDiff3LineListUsingAC(diffList13, diff3LineList);
    updateDiff3LineListUsingBC(diffList23, diff3LineList);

    return diff3LineList;
}

void trimDiff3LineList(ref Diff3LineList d3ll,
                       shared ILineProvider lpA,
                       shared ILineProvider lpB,
                       shared ILineProvider lpC)
{
    auto r3 = d3ll[];
    auto r3a = d3ll[];
    auto r3b = d3ll[];
    auto r3c = d3ll[];

    int line = 0;
    int lineA = 0;
    int lineB = 0;
    int lineC = 0;

    for(; !r3.empty(); r3.popFront(), line++)
    {
        if( line > lineA && r3.front.lineA != -1 && r3a.front.lineB != -1 && r3a.front.bBEqC &&
            lpA.get(r3.front.lineA) == lpB.get(r3a.front.lineB) )
        {
            r3a.front.lineA = r3.front.lineA;
            r3a.front.bAEqB = true;
            r3a.front.bAEqC = true;

            r3.front.lineA = -1;
            r3.front.bAEqB = false;
            r3.front.bAEqC = false;

            r3a.popFront();
            lineA++;
        }

        if( line > lineB && r3.front.lineB != -1 && r3b.front.lineA != -1 && r3b.front.bAEqC &&
            lpB.get(r3.front.lineB) == lpA.get(r3b.front.lineA) )
        {
            r3b.front.lineB = r3.front.lineB;
            r3b.front.bAEqB = true;
            r3b.front.bBEqC = true;

            r3.front.lineB = -1;
            r3.front.bAEqB = false;
            r3.front.bBEqC = false;

            r3b.popFront();
            lineB++;
        }

        if( line > lineC && r3.front.lineC != -1 && r3c.front.lineA != -1 && r3c.front.bAEqB &&
            lpC.get(r3.front.lineC) == lpA.get(r3c.front.lineA) )
        {
            r3c.front.lineC = r3.front.lineC;
            r3c.front.bAEqC = true;
            r3c.front.bBEqC = true;

            r3.front.lineC = -1;
            r3.front.bAEqC = false;
            r3.front.bBEqC = false;

            r3c.popFront();
            lineC++;
        }

        if( line > lineA && r3.front.lineA != -1 && !r3.front.bAEqB && !r3.front.bAEqC )
        {
            r3a.front.lineA = r3.front.lineA;
            r3.front.lineA = -1;
            assert(!r3.front.bAEqB);
            assert(!r3.front.bAEqC);

            if(r3a.front.lineB != -1 && lpA.get(r3a.front.lineA) == lpB.get(r3a.front.lineB))
            {
                r3a.front.bAEqB = true;
            }
            if((r3a.front.bAEqB && r3a.front.bBEqC) ||
               (r3a.front.lineC != -1 && lpA.get(r3a.front.lineA) == lpC.get(r3a.front.lineC)))
            {
                r3a.front.bAEqC = true;
            }

            r3a.popFront();
            lineA++;
        }

        if( line > lineB && r3.front.lineB != -1 && !r3.front.bAEqB && !r3.front.bBEqC )
        {
            r3b.front.lineB = r3.front.lineB;
            r3.front.lineB = -1;
            assert(!r3.front.bAEqB);
            assert(!r3.front.bBEqC);

            if(r3b.front.lineA != -1 && lpA.get(r3b.front.lineA) == lpB.get(r3b.front.lineB))
            {
                r3b.front.bAEqB = true;
            }
            if((r3b.front.bAEqB && r3b.front.bAEqC) ||
               (r3b.front.lineC != -1 && lpB.get(r3b.front.lineB) == lpC.get(r3b.front.lineC)))
            {
                r3b.front.bBEqC = true;
            }

            r3b.popFront();
            lineB++;
        }

        if( line > lineC && r3.front.lineC != -1 && !r3.front.bAEqC && !r3.front.bBEqC )
        {
            r3c.front.lineC = r3.front.lineC;
            r3.front.lineC = -1;
            assert(!r3.front.bAEqC);
            assert(!r3.front.bBEqC);

            if(r3c.front.lineA != -1 && lpA.get(r3c.front.lineA) == lpC.get(r3c.front.lineC))
            {
                r3c.front.bAEqC = true;
            }
            if((r3c.front.bAEqC && r3c.front.bAEqB) ||
               (r3c.front.lineB != -1 && lpB.get(r3c.front.lineB) == lpC.get(r3c.front.lineC)))
            {
                r3c.front.bBEqC = true;
            }

            r3c.popFront();
            lineC++;
        }

        if( line > lineA && line > lineB && r3.front.lineA != -1 &&
            r3.front.bAEqB && !r3.front.bAEqC )
        {
            /* if A and B are equal and not equal to C, then move them up to the first position where both A and B are -1 */

            auto r = (lineA > lineB) ? r3a : r3b;
            int  l = (lineA > lineB) ? lineA : lineB;

            {
                r.front.lineA = r3.front.lineA;
                r.front.lineB = r3.front.lineB;
                r.front.bAEqB = true;

                if(r.front.lineC != -1 && lpA.get(r.front.lineA) == lpC.get(r.front.lineC))
                {
                    r.front.bAEqC = true;
                    r.front.bBEqC = true;
                }

                r3.front.lineA = -1;
                r3.front.lineB = -1;
                r3.front.bAEqB = false;
                r3a = r;
                r3b = r;
                r3a.popFront();
                r3b.popFront();

                lineA = l + 1;
                lineB = l + 1;
            }
        }
        else if( line > lineA && line > lineC && r3.front.lineA != -1 && 
                 r3.front.bAEqC && !r3.front.bAEqB)
        {
            /* if A and C are equal and not equal to B, then move them up to the first position where both A and C are -1 */

            auto r = (lineA > lineC) ? r3a : r3c;
            int  l = (lineA > lineC) ? lineA : lineC;

            {
                r.front.lineA = r3.front.lineA;
                r.front.lineC = r3.front.lineC;
                r.front.bAEqC = true;

                if(r.front.lineB != -1 && lpA.get(r.front.lineA) == lpB.get(r.front.lineB))
                {
                    r.front.bAEqB = true;
                    r.front.bBEqC = true;
                }

                r3.front.lineA = -1;
                r3.front.lineC = -1;
                r3.front.bAEqC = false;
                r3a = r;
                r3c = r;
                r3a.popFront();
                r3c.popFront();

                lineA = l + 1;
                lineC = l + 1;
            }
        }
        else if( line > lineB && line > lineC && r3.front.lineB != -1 && 
                 r3.front.bBEqC && !r3.front.bAEqC)
        {
            /* if B and C are equal and not equal to A, then move them up to the first position where both B and C are -1 */

            auto r = (lineB > lineC) ? r3b : r3c;
            int  l = (lineB > lineC) ? lineB : lineC;

            {
                r.front.lineB = r3.front.lineB;
                r.front.lineC = r3.front.lineC;
                r.front.bBEqC = true;

                if(r.front.lineA != -1 && lpA.get(r.front.lineA) == lpB.get(r.front.lineB))
                {
                    r.front.bAEqB = true;
                    r.front.bAEqC = true;
                }

                r3.front.lineB = -1;
                r3.front.lineC = -1;
                r3.front.bBEqC = false;
                r3b = r;
                r3c = r;
                r3b.popFront();
                r3c.popFront();

                lineB = l + 1;
                lineC = l + 1;
            }
        }

        if(r3.front.lineA != -1)
        {
            lineA = line + 1;
            r3a = r3;
            r3a.popFront();
        }
        if(r3.front.lineB != -1)
        {
            lineB = line + 1;
            r3b = r3;
            r3b.popFront();
        }
        if(r3.front.lineC != -1)
        {
            lineC = line + 1;
            r3c = r3;
            r3c.popFront();
        }
    }

    /*
     * TODO: find a cleaner way to remove empty entries.
    d3ll = remove!(d => (d.lineA == -1 &&
                         d.lineB == -1 &&
                         d.lineC == -1))(d3ll[]);*/
    r3 = d3ll[];
    while(!r3.empty())
    {
        auto el = r3.take(1);
        r3.popFront();
        if(el.front.lineA == -1 &&
           el.front.lineB == -1 &&
           el.front.lineC == -1)
        {
            d3ll.linearRemove(el);
        }
    }

}

version(unittest)
{
    auto lp = new shared FakeLineProvider();
}

unittest
{
    /* Check if lines from A are compacted in the simplest case */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false,  1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false,  1, -1, -1),
                                          ]);
    trimDiff3LineList(d3ll, lp, lp, lp);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  1, -1, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false,  1, -1, -1));
    assertEqual(d3ltuples.length, 2);
}

unittest
{
    /* Check if lines from B are compacted in the simplest case */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1,  1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1,  1, -1),
                                          ]);
    trimDiff3LineList(d3ll, lp, lp, lp);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1,  1, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1,  1, -1));
    assertEqual(d3ltuples.length, 2);
}

unittest
{
    /* Check if lines from C are compacted in the simplest case */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1,  1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false, -1, -1,  1),
                                          ]);
    trimDiff3LineList(d3ll, lp, lp, lp);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1, -1,  1));
    assertEqual(d3ltuples[1], tuple(false, false, false, -1, -1,  1));
    assertEqual(d3ltuples.length, 2);
}


DiffList calcDiff(string line1, string line2, int match, int maxSearchRange)
{
    DiffList diffList;

    auto line1array = array(cast(ubyte[])line1);
    auto line2array = array(cast(ubyte[])line2);

    /* TODO: this algorithm must be done char by char, but the count in the
     * Diff's returned should be in bytes so it can be used for splicing the
     * string */

    auto r1 = line1array;
    auto r2 = line2array;

    for(;;)
    {
        int nofEquals = 0;
        while(!r1.empty && !r2.empty && r1.front == r2.front)
        {
            r1.popFront();
            r2.popFront();
            nofEquals++;
        }

        bool bestValid = false;
        int bestI1 = 0;
        int bestI2 = 0;
        int i1 = 0;
        int i2 = 0;

        // Look for a character that occurs in both r1 and r2 and that is closest to the current position
        for(i1 = 0; ; i1++)
        {
            // Stop looking ahead in r1 if we've already found a match that is closer to the current position
            if(i1 == r1.length || (bestValid && (i1 >= bestI1 + bestI2)))
            {
                break;
            }
            for(i2 = 0; i2 < maxSearchRange; i2++)
            {
                // Stop looking ahead in r2 if we've already found amatch that is closer to the current position
                if(i2 == r2.length || (bestValid && ((i1 + i2) >= (bestI1 + bestI2))))
                {
                    break;
                }
                // If we've found a matching character and one of the following holds..
                // - it is about as far from the previous set of matching chars in r1 as in r2
                // - it is the last char in both r1 and r2
                // - the next char in r1 and r2 also matches
                else if( (r1[i1] == r2[i2]) &&
                         ( match == 1 ||
                           abs(i1 - i2) < 3 ||
                           (i1 + 1 == r1.length && i2 + 1 == r2.length) ||
                           (i1 + 1 != r1.length && i2 + 1 != r2.length && r1[i1 + 1] == r2[i2 + 1]) ) )
                {
                    // I don't think this can ever be false
                    assert(i1 + i2 < bestI1 + bestI2 || !bestValid);
                    if(i1 + i2 < bestI1 + bestI2 || !bestValid)
                    {
                        bestI1 = i1;
                        bestI2 = i2;
                        bestValid = true;
                        break;
                    }
                }
            }
        }


        // The match was found using the strict search. Go back if there are non-strict
        // matches.
        while(bestI1 > 0 && bestI2 > 0 && r1[bestI1 - 1] == r2[bestI2 - 1])
        {
            bestI1--;
            bestI2--;
            // This should never happen, because the code makes no distinction between strict and non-strict matches
            assert(false);
        }

        bool endReached = false;
        if(bestValid)
        {
            // continue somehow
            Diff d = Diff(nofEquals, bestI1, bestI2);
            diffList.insertBack(d);

            r1.popFrontN(bestI1);
            r2.popFrontN(bestI2);
        }
        else
        {
            // Nothing else to match.
            Diff d = Diff(cast(uint)nofEquals, cast(uint)r1.length, cast(uint)r2.length);
            diffList.insertBack(d);

            endReached = true;
        }

        // Sometimes the algorithm that chooses the first match unfortunately chooses
        // a match where later actually equal parts don't match anymore.
        // A different match could be achieved, if we start at the end.
        // Do it, if it would be a better match.
        int nofUnmatched = 0;
        auto ru1 = line1array[0..$-r1.length];
        auto ru2 = line2array[0..$-r2.length];

        while(!ru1.empty && !ru2.empty && ru1.back == ru2.back)
        {
            nofUnmatched++;
            ru1.popBack();
            ru2.popBack();
        }


        Diff d = diffList.back;
        if(nofUnmatched > 0)
        {
            // We want to go backwards the nofUnmatched elements and redo
            // the matching
            d = diffList.back;
            Diff origBack = d;
            diffList.removeBack();


            while(nofUnmatched > 0)
            {
                if(d.diff1 > 0 && d.diff2 > 0)
                {
                    d.diff1--;
                    d.diff2--;
                    nofUnmatched--;
                }
                else if(d.nofEquals > 0)
                {
                    d.nofEquals--;
                    nofUnmatched--;
                }

                if(d.nofEquals == 0 && (d.diff1 == 0 || d.diff2 == 0) && nofUnmatched > 0)
                {
                    if(diffList.empty)
                    {
                        break;
                    }
                    d.nofEquals += diffList.back.nofEquals;
                    d.diff1 += diffList.back.diff1;
                    d.diff2 += diffList.back.diff2;
                    diffList.removeBack();
                    endReached = false;
                }
            }


            if(endReached)
            {
                diffList.insertBack(origBack);
            }
            else
            {
                assert(nofUnmatched == 0);
                r1 = line1array[ru1.length + nofUnmatched..$];
                r2 = line2array[ru2.length + nofUnmatched..$];
                diffList.insertBack(d);
            }
        }

        if(endReached)
        {
            break;
        }
    }

    verifyDiffList(diffList, cast(int)line1array.length, cast(int)line2array.length);

    return diffList;
}



unittest
{
    Diff[] mirrorDiffArray(Diff[] diffArray)
    {
        Diff[] mirroredArray = diffArray.dup;

        foreach(ref d; mirroredArray)
        {
            swap(d.diff1, d.diff2);
        }

        return mirroredArray;
    }

    // unittest for mirrorDiffArray
    auto arr1 = [Diff(1,2,3)];
    auto arr2 = mirrorDiffArray(arr1);
    assertEqual(arr1[0], Diff(1,2,3));
    assertEqual(arr2[0], Diff(1,3,2));

    Diff[] normalize(Diff[] diffArray)
    {
        Diff[] normalizedDiffArray;

        Diff newD;
        foreach(d; diffArray)
        {
            if(newD.diff1 == 0 && newD.diff2 == 0)
            {
                newD.nofEquals += d.nofEquals;
                d.nofEquals = 0;
            }
            if(d.nofEquals == 0)
            {
                newD.diff1 += d.diff1;
                newD.diff2 += d.diff2;
            }
            else
            {
                normalizedDiffArray ~= newD;
                newD = d;
            }
        }
        if(newD != Diff(0,0,0))
        {
            normalizedDiffArray ~= newD;
        }

        return normalizedDiffArray;
    }

    // unittest for normalize
    assertEqual(normalize([Diff(3,0,0),Diff(0,1,2)]), [Diff(3,1,2)]); // trivially mergable
    assertEqual(normalize([Diff(0,1,1),Diff(4,0,0)]), [Diff(0,1,1), Diff(4,0,0)]); // trivially not mergable
    assertEqual(normalize([Diff(3,0,0),Diff(4,1,2)]), [Diff(7,1,2)]); // mergeable because no diff in first
    assertEqual(normalize([Diff(3,1,0),Diff(4,1,2)]), [Diff(3,1,0), Diff(4,1,2)]); // not mergable because diff1 in first
    assertEqual(normalize([Diff(3,0,1),Diff(4,1,2)]), [Diff(3,0,1), Diff(4,1,2)]); // not mergable because diff2 in first
    assertEqual(normalize([Diff(3,1,0),Diff(0,1,2)]), [Diff(3,2,2)]); // mergable despite diff1 in first because no equal in second
    assertEqual(normalize([Diff(3,0,1),Diff(0,1,2)]), [Diff(3,1,3)]); // mergable despite diff2 in first because no equal in second


    void testCalcDiffIncludingMirrored(string line1, string line2, int match, int maxSearchRange, Diff[] expectedDiffArray, string file = __FILE__, int line = __LINE__)
    {
        DiffList dl;
        dl = calcDiff(line1, line2, match, maxSearchRange);
        assertEqual(normalize(array(dl)), expectedDiffArray, format("test case at %s:%d (regular) failed", file, line));

        auto mirroredDiffArray = mirrorDiffArray(expectedDiffArray);
        dl = calcDiff(line2, line1, match, maxSearchRange);
        assertEqual(normalize(array(dl)), mirroredDiffArray, format("test case at %s:%d (mirrored) failed", file, line));
    }

    testCalcDiffIncludingMirrored("match", "match", 2, 500, [Diff(5,0,0)]);

    testCalcDiffIncludingMirrored("matmatch", "match", 2, 500, [Diff(0,3,0), Diff(5,0,0)]);
    testCalcDiffIncludingMirrored("mat_match", "match", 2, 500, [Diff(0,4,0), Diff(5,0,0)]);
    testCalcDiffIncludingMirrored("mat_______match", "match", 2, 500, [Diff(0,10,0), Diff(5, 0, 0)]);

    testCalcDiffIncludingMirrored("amat_match", "bmatch", 2, 500, [Diff(0,5,1), Diff(5,0,0)]);

    testCalcDiffIncludingMirrored("matchtch", "match", 2, 500, [Diff(5,3,0)]);
    testCalcDiffIncludingMirrored("match_tch", "match", 2, 500, [Diff(5,4,0)]);
    testCalcDiffIncludingMirrored("match_______tch", "match", 2, 500, [Diff(5,10,0)]);

    testCalcDiffIncludingMirrored("παρ", "παρ", 2, 500, [Diff(6, 0, 0)]);
    testCalcDiffIncludingMirrored("ｔｅｒ", "ｔｅｒ", 2, 500, [Diff(9, 0, 0)]);
    testCalcDiffIncludingMirrored("ｅｒ", "ｔｅｒ", 2, 500, [Diff(0, 0, 3), Diff(6, 0, 0)]);
}

static void verifyDiffList(DiffList diffList, int size1, int size2)
{
    int l1 = 0;
    int l2 = 0;

    foreach(entry; diffList)
    {
        l1 += entry.nofEquals + entry.diff1;
        l2 += entry.nofEquals + entry.diff2;
    }

    assertEqual(l1, size1);
    assertEqual(l2, size2);
}

DiffList fineDiff(int k1,
                  int k2,
                  string line1,
                  string line2)
{
    int maxSearchLength = 500;
    bool filesIdentical = true;

    if( (k1 == -1 && k2 != -1) ||
        (k1 != -1 && k2 == -1) )
    {
        filesIdentical = false;
    }

    DiffList diffList;
    int line1Length = (k1 == -1) ? 0 : to!int(line1.length);
    int line2Length = (k2 == -1) ? 0 : to!int(line2.length);
    if(k1 == -1 || k2 == -1)
    {
        diffList.insertBack(Diff(0, line1Length, line2Length));
    }
    else
    {
        if(line1.length == line2.length && line1 == line2)
        {
            diffList.insertBack(Diff(to!int(line1.length), 0, 0));
        }
        else
        {
            filesIdentical = false;
            diffList = calcDiff(line1, line2, 2, maxSearchLength);

            // Optimize the diff list
            bool fineDiffUseless = true;
            foreach(dli; diffList)
            {
                if(dli.nofEquals >= 4)
                {
                    fineDiffUseless = false;
                    break;
                }
            }

            bool first = true;
            foreach(ref dli; diffList)
            {
                if(dli.nofEquals < 4 &&
                   (dli.diff1 > 0 || dli.diff2 > 0) &&
                   (fineDiffUseless || !first))
                {
                    dli.diff1 += dli.nofEquals;
                    dli.diff2 += dli.nofEquals;
                    dli.nofEquals = 0;
                }
                first = false;
            }

        }
    }

    return diffList;
}

unittest
{
    setlocale(LC_ALL, "");

    assertEqual(array(fineDiff(0, 0, "same_", "same_")), [Diff(5,0,0)]);
    assertEqual(array(fineDiff(0, 0, "same_a", "same_b")), [Diff(5,1,1)]);
    assertEqual(array(fineDiff(0, 0, "same_a", "same_bc")), [Diff(5,1,2)]);

    string four_bytes_two_columns = "\U00020000";    // <CJK Ideograph Extension B, First>
    string four_bytes_unprintable = "\U0001F600";    // "GRINNING FACE"


    assertEqual(array(fineDiff(0, 0, "same" ~ two_bytes_one_column, "same")), [Diff(4,2,0)]);
    assertEqual(array(fineDiff(0, 0, "same" ~ three_bytes_one_column, "same")), [Diff(4,3,0)]);
    assertEqual(array(fineDiff(0, 0, "same" ~ three_bytes_two_columns, "same")), [Diff(4,3,0)]);

    assertEqual(array(fineDiff(0, 0, "ae" ~ two_bytes_zero_columns ~ "\n", "ae\n")), [Diff(0,4,2), Diff(1,0,0)]);
    assertEqual(array(fineDiff(0, -1, "ae" ~ two_bytes_zero_columns ~ "\n", "")), [Diff(0,5,0)]);
    assertEqual(array(fineDiff(0, -1, "ae\n", "")), [Diff(0,3,0)]);
}


class DiffListIterator
{
    private DiffList.Range m_diffListRange;
    private int m_whichFile;
    private Diff m_head;

    this(DiffList diffList, int whichFile)
    {
        m_diffListRange = diffList[];
        m_whichFile = whichFile;
    }

    private ref int diffField(ref Diff d)
    {
        switch(m_whichFile)
        {
        case 0:
            return d.diff1;
        case 1:
            return d.diff2;
        default:
            assert(false);
        }
    }

    private void updateHead()
    {
        while(m_head.nofEquals == 0 && diffField(m_head) == 0 && !m_diffListRange.empty)
        {
            m_head = m_diffListRange.front;
            m_diffListRange.popFront();
        }
    }

    bool atEnd()
    {
        updateHead();
        return m_head.nofEquals == 0 && diffField(m_head) == 0;
    }

    Tuple!(bool, int) getNextRun()
    {
        updateHead();
        if(m_head.nofEquals > 0)
        {
            return tuple(true, m_head.nofEquals);
        }
        else
        {
            //assert(diffField(m_head) > 0);
            return tuple(false, diffField(m_head));
        }
    }

    void advance(int n)
    {
        while(n > 0)
        {
            updateHead();

            auto step = min(n, m_head.nofEquals);
            n -= step;
            m_head.nofEquals -= step;

            if(n > 0)
            {
                step = min(n, diffField(m_head));
                n -= step;
                diffField(m_head) -= step;
            }
        }
    }
}

private DiffList toDiffList(Diff[] diffArray)
{
    DiffList diffList;
    foreach(d; diffArray)
    {
        diffList.insertBack(d);
    }
    return diffList;
}

unittest
{

    DiffListIterator it;

    it = new DiffListIterator(toDiffList([Diff(1,2,3)]), 0);
    assertEqual(it.getNextRun(), tuple(true, 1));

    it = new DiffListIterator(toDiffList([Diff(0,2,3)]), 0);
    assertEqual(it.getNextRun(), tuple(false, 2));

    it = new DiffListIterator(toDiffList([Diff(0,2,3)]), 1);
    assertEqual(it.getNextRun(), tuple(false, 3));

    it = new DiffListIterator(toDiffList([Diff(3,5,7)]), 0);
    it.advance(2);
    assertEqual(it.getNextRun(), tuple(true, 1));

    it = new DiffListIterator(toDiffList([Diff(3,5,7)]), 0);
    it.advance(3);
    assertEqual(it.getNextRun(), tuple(false, 5));

    it = new DiffListIterator(toDiffList([Diff(3,5,7)]), 0);
    it.advance(4);
    assertEqual(it.getNextRun(), tuple(false, 4));

    it = new DiffListIterator(toDiffList([Diff(3,5,7)]), 1);
    it.advance(4);
    assertEqual(it.getNextRun(), tuple(false, 6));

    it = new DiffListIterator(toDiffList([Diff(3,5,7), Diff(3,2,1)]), 0);
    it.advance(10);
    assertEqual(it.getNextRun(), tuple(true, 1));

    // Check that advancing does not modify the original list
    auto dl = toDiffList([Diff(3,5,7), Diff(3,2,1)]);
    it = new DiffListIterator(dl, 0);
    it.advance(10);
    assertEqual(array(dl), [Diff(3,5,7), Diff(3,2,1)]);


}

DList!StyleFragment lineStyleFromFineDiffs(DiffListIterator it1,
                                           DiffListIterator it2,
                                           DiffStyle sameInIt1,
                                           DiffStyle sameInIt2)
{
    DList!StyleFragment styleList;

    DiffStyle style = DiffStyle.ALL_SAME;
    int run = 0;

    while(true)
    {
        int step;

        auto t1 = it1.getNextRun();
        auto t2 = it2.getNextRun();

        bool equal1 = t1[0];
        bool equal2 = t2[0];
        int length1 = t1[1];
        int length2 = t2[1];

        // check if either of the iterators is at its end
        if(it1.atEnd() || it2.atEnd())
        {
            break;
        }

        DiffStyle nextStyle = equal1 ? (equal2 ? DiffStyle.ALL_SAME : sameInIt1)
                                     : (equal2 ? sameInIt2 : DiffStyle.DIFFERENT);

        if(nextStyle != style)
        {
            if(run > 0)
            {
                styleList.insertBack(StyleFragment(style, run));
                run = 0;
            }
            style = nextStyle;
        }

        step = min(length1, length2);

        run += step;
        it1.advance(step);
        it2.advance(step);
    }

    assert(it1.atEnd() && it2.atEnd());

    if(run != 0)
    {
        styleList.insertBack(StyleFragment(style, run));
    }

    return styleList;
}

unittest
{
    DiffListIterator it1, it2;
    DList!StyleFragment dl;

    // Both identical
    it1 = new DiffListIterator(toDiffList([Diff(1,2,3)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(1,2,3)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.ALL_SAME, 1),
                            StyleFragment(DiffStyle.DIFFERENT, 2)]);

    // Difference trumps equal in same Diff
    it1 = new DiffListIterator(toDiffList([Diff(3,2,2)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(1,4,3)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.ALL_SAME, 1),
                            StyleFragment(DiffStyle.A_B_SAME, 2),
                            StyleFragment(DiffStyle.DIFFERENT, 2)]);

    // Difference trumps equal in next Diff
    it1 = new DiffListIterator(toDiffList([Diff(2,1,1), Diff(1,1,1)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(1,4,3)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.ALL_SAME, 1),
                            StyleFragment(DiffStyle.A_B_SAME, 1),
                            StyleFragment(DiffStyle.DIFFERENT, 1),
                            StyleFragment(DiffStyle.A_B_SAME, 1),
                            StyleFragment(DiffStyle.DIFFERENT, 1)]);

    // Difference on either side trumps equal in other
    it1 = new DiffListIterator(toDiffList([Diff(2,2,0), Diff(2,0,0)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(0,2,0), Diff(2,2,0)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.A_B_SAME, 2),
                            StyleFragment(DiffStyle.A_C_SAME, 2),
                            StyleFragment(DiffStyle.A_B_SAME, 2)]);

    // Equal in the middle of a stretch of diff
    it1 = new DiffListIterator(toDiffList([Diff(0,2,0), Diff(3,4,0)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(9,0,0)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.A_C_SAME, 2),
                            StyleFragment(DiffStyle.ALL_SAME, 3),
                            StyleFragment(DiffStyle.A_C_SAME, 4)]);

    // Diff in the middle of a stretch of equal
    it1 = new DiffListIterator(toDiffList([Diff(2,3,0), Diff(4,0,0)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(9,0,0)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.ALL_SAME, 2),
                            StyleFragment(DiffStyle.A_C_SAME, 3),
                            StyleFragment(DiffStyle.ALL_SAME, 4)]);

    it1 = new DiffListIterator(toDiffList([Diff(2, 18, 0), Diff(1, 0, 0)]), 0);
    it2 = new DiffListIterator(toDiffList([Diff(0, 1, 36), Diff(1, 19, 0)]), 0);
    dl = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);
    assertEqual(array(dl), [StyleFragment(DiffStyle.A_B_SAME, 1),
                            StyleFragment(DiffStyle.ALL_SAME, 1),
                            StyleFragment(DiffStyle.DIFFERENT, 18),
                            StyleFragment(DiffStyle.A_B_SAME, 1)]);
}

void determineFineDiffStylePerLine(ref Diff3Line d3l,
                                   shared ILineProvider lpA,
                                   shared ILineProvider lpB,
                                   shared ILineProvider lpC)
{
    auto fineDiffAB = fineDiff(d3l.line(0),
                               d3l.line(1),
                               (d3l.line(0) == -1) ? "" : lpA.get(d3l.line(0)),
                               (d3l.line(1) == -1) ? "" : lpB.get(d3l.line(1)));
    auto fineDiffAC = fineDiff(d3l.line(0),
                               d3l.line(2),
                               (d3l.line(0) == -1) ? "" : lpA.get(d3l.line(0)),
                               (d3l.line(2) == -1) ? "" : lpC.get(d3l.line(2)));
    auto fineDiffBC = fineDiff(d3l.line(1),
                               d3l.line(2),
                               (d3l.line(1) == -1) ? "" : lpB.get(d3l.line(1)),
                               (d3l.line(2) == -1) ? "" : lpC.get(d3l.line(2)));

    DiffListIterator it1, it2;

    it1 = new DiffListIterator(fineDiffAB, 0);
    it2 = new DiffListIterator(fineDiffAC, 0);
    d3l.styleA = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.A_C_SAME);

    it1 = new DiffListIterator(fineDiffAB, 1);
    it2 = new DiffListIterator(fineDiffBC, 0);
    d3l.styleB = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_B_SAME, DiffStyle.B_C_SAME);

    it1 = new DiffListIterator(fineDiffAC, 1);
    it2 = new DiffListIterator(fineDiffBC, 1);
    d3l.styleC = lineStyleFromFineDiffs(it1, it2, DiffStyle.A_C_SAME, DiffStyle.B_C_SAME);
}


void determineFineDiffStyle(Diff3LineList diff3LineList,
                            shared ILineProvider lpA,
                            shared ILineProvider lpB,
                            shared ILineProvider lpC)
{
    foreach(ref d3l; diff3LineList)
    {
        determineFineDiffStylePerLine(d3l, lpA, lpB, lpC);
    }
}

