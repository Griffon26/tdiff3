import std.container;
import std.stdio;
import std.typecons;

import common;
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
            writeln("case equals");
            Diff3Line d3l = Diff3Line.init;
            d3l.bAEqB = true;
            d3l.lineA = lineA++;
            d3l.lineB = lineB++;
            diff3LineList.insertBack(d3l);
            d.nofEquals--;
        }
        while(d.diff1 > 0 && d.diff2 > 0)
        {
            writeln("case both diff");
            Diff3Line d3l = Diff3Line.init;
            d3l.lineA = lineA++;
            d3l.lineB = lineB++;
            diff3LineList.insertBack(d3l);
            d.diff1--;
            d.diff2--;
        }
        while(d.diff1 > 0)
        {
            writeln("case diff1");
            Diff3Line d3l = Diff3Line.init;
            d3l.lineA = lineA++;
            diff3LineList.insertBack(d3l);
            d.diff1--;
        }
        while(d.diff2 > 0)
        {
            writeln("case diff2");
            Diff3Line d3l = Diff3Line.init;
            d3l.lineB = lineB++;
            diff3LineList.insertBack(d3l);
            d.diff2--;
        }
    }
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
    assertEqual(r3b.front.lineB, r3c.front.lineC);

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
        while(d.diff1 > 0)
        {
            auto r3 = r3b;
            while(r3.front.lineB != lineB)
                r3.popFront();
            if(r3 != r3b && !r3.front.bAEqB)
            {
                Diff3Line d3l;
                d3l.lineB = lineB;
                diff3LineList.insertBefore(r3b, d3l);
                r3.front.lineB = -1;
            }
            else
            {
                r3b = r3;
            }
            d.diff1--;
            lineB++;
            r3b.popFront();

            if(d.diff2 > 0)
            {
                d.diff2--;
                lineC++;
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
     * Check  
    Diff3LineList d3ll = toDiff3LineList([tuple(false, false, false, -1, -1, -1),
                                          tuple(false, false, false,  0,  0, -1)
                                          ]);
    DiffList dl = [Diff(0,1,1),
                   Diff(1,0,0)];

    updateDiff3LineListUsingAC(dl, d3ll);

    auto d3ltuples = d3ll.toTuples;
    assertEqual(d3ltuples[0], tuple(false, false, false, -1, -1,  0));
    assertEqual(d3ltuples[1], tuple(false, false, false,  0,  0, -1));
    assertEqual(d3ltuples[2], tuple(false, true,  false,  1,  1,  1));
    assertEqual(d3ltuples.length, 3);
    */
}

Diff3LineList calcDiff3LineList(DiffList diffList12, DiffList diffList13, DiffList diffList23)
{
    Diff3LineList diff3LineList;

    updateDiff3LineListUsingAB(diffList12, diff3LineList);
    updateDiff3LineListUsingAC(diffList13, diff3LineList);
    updateDiff3LineListUsingBC(diffList23, diff3LineList);

    return diff3LineList;
}


