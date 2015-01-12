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

import std.container;
import std.stdio;
import std.typecons;

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

