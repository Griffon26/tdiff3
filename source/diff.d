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
import std.container;
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.typecons;
import std.utf;

import common;
import ilineprovider;
import myassert;

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
        if(d.diff1 > 0)
        {
            auto r3to = r3b;
            auto r3from = r3b;
            while(r3from.front.lineB != lineB)
            {
                assert(r3from.front.lineB == -1);
                r3from.popFront();
            }
            while(!r3from.empty() && r3to != r3from && !r3from.front.bAEqB && d.diff1 > 0)
            {
                r3to.front.lineB = r3from.front.lineB;
                r3from.front.lineB = -1;
                r3to.popFront();
                r3from.popFront();
                lineB++;
                d.diff1--;
            }
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
    assertEqual(d3ltuples[0], tuple(false, false, false,  4,  0,  7));
    assertEqual(d3ltuples[1], tuple(false, false, false,  5,  1,  8));
    assertEqual(d3ltuples[2], tuple(false, false, false,  6, -1,  9));
    assertEqual(d3ltuples.length, 3);
}

version(old)
{
unittest
{
    /* Test for while(d.diff1 > 0)
     * Check that B (line 2) is moved up enough to make room for an equal C (line 0) */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  4, -1,  0),
                                          tuple(false, false, false,  5,  0,  1),
                                          tuple(false, false, false,  6,  1,  2),
                                          tuple(false, false, false,  7,  2,  3)
                                          ]);
    DiffList dl = [Diff(0,2,0)];

    updateDiff3LineListUsingBC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1,  0, -1));
    assertEqual(d3ltuples[1], tuple(false, false, false,  4, -1,  0));
    assertEqual(d3ltuples[2], tuple(false, false, false, -1,  1, -1));
    assertEqual(d3ltuples[3], tuple(false, false, false,  5, -1,  1));
    assertEqual(d3ltuples[4], tuple(false, false, false,  6, -1,  2));
    assertEqual(d3ltuples[5], tuple(false, false, false,  7,  2,  3));
    assertEqual(d3ltuples.length, 6);
}
}
else
{
unittest
{
    /* Test for while(d.diff1 > 0)
     * Check that B (line 2) is moved up enough to make room for an equal C (line 0) */
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false,  4, -1,  0),
                                          tuple(false, false, false,  5,  0,  1),
                                          tuple(false, false, false,  6,  1,  2),
                                          tuple(false, false, false,  7,  2,  3)
                                          ]);
    DiffList dl = [Diff(0,2,0)];

    updateDiff3LineListUsingBC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false,  4,  0,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false,  5,  1,  1));
    assertEqual(d3ltuples[2], tuple(false, false, false,  6, -1,  2));
    assertEqual(d3ltuples[3], tuple(false, false, false,  7,  2,  3));
    assertEqual(d3ltuples.length, 4);
}
}

version(old){
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
    assertEqual(d3ltuples[3], tuple(false, false, false, -1, -1, -1));
    assertEqual(d3ltuples[4], tuple(false, false, false,  5, -1,  1));
    assertEqual(d3ltuples[5], tuple(false, false, false,  6, -1,  2));
    assertEqual(d3ltuples[6], tuple(false, false, false,  7, -1,  3));
    assertEqual(d3ltuples.length, 7);
}
}
else
{
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

        if( line > lineC && r3.front.lineC != -1 && r3.front.bAEqC && r3.front.bBEqC )
        {
            r3c.front.lineC = r3.front.lineC;
            r3.front.lineC = -1;

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
}

DiffList calcDiff(string line1, string line2, int match, int maxSearchRange)
{
    DiffList diffList;

    auto r1 = array(line1);
    auto r2 = array(line2);

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
        auto ru1 = array(line1)[0..$-r1.length];
        auto ru2 = array(line2)[0..$-r2.length];

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
                r1 = array(line1)[ru1.length + nofUnmatched..$];
                r2 = array(line2)[ru2.length + nofUnmatched..$];
                diffList.insertBack(d);
            }
        }

        if(endReached)
        {
            break;
        }
    }

    verifyDiffList(diffList, cast(int)array(line1).length, cast(int)array(line2).length);

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

    testCalcDiffIncludingMirrored("παρ", "παρ", 2, 500, [Diff(3, 0, 0)]);
    testCalcDiffIncludingMirrored("ｔｅｒ", "ｔｅｒ", 2, 500, [Diff(3, 0, 0)]);
    testCalcDiffIncludingMirrored("ｅｒ", "ｔｅｒ", 2, 500, [Diff(0, 0, 1), Diff(2, 0, 0)]);
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

bool fineDiff(ref Diff3LineList d3ll,
              DiffSelection diffSel,
              shared ILineProvider lpOne,
              shared ILineProvider lpOther)
{
    int maxSearchLength = 500;
    bool filesIdentical = true;

    for(auto r = d3ll[]; !r.empty(); r.popFront())
    {
        auto k1 = r.front.line(left(diffSel));
        auto k2 = r.front.line(right(diffSel));

        if( (k1 == -1 && k2 != -1) ||
            (k1 != -1 && k2 == -1) )
        {
            filesIdentical = false;
        }

        if(k1 != -1 && k2 != -1)
        {
            auto line1 = lpOne.get(k1);
            auto line2 = lpOther.get(k2);

            if( (line1.length != line2.length) || line1 != line2 )
            {
                filesIdentical = false;
                DiffList diffList = calcDiff(line1, line2, 2, maxSearchLength);

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

                r.front.fineDiff(diffSel) = diffList;
            }
        }
    }

    return filesIdentical;
}
