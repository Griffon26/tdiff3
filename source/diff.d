import std.container;
import std.stdio;
import std.typecons;

import dunit;

import common;

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

Tuple!(bool, bool, bool, int, int, int) toResult(Diff3Line d3l)
{
    return tuple(d3l.bAEqB, d3l.bAEqC, d3l.bBEqC, d3l.lineA, d3l.lineB, d3l.lineC);
}

unittest
{

    DiffList dl = [Diff(1, 1, 2)];
    Diff3LineList d3ll;

    updateDiff3LineListUsingAB(dl, d3ll);

    Tuple!(bool, bool, bool, int, int, int)[] d3ltuples;
    foreach(d3l; d3ll)
    {
        d3ltuples ~= toResult(d3l);
    }

    assertEquals(d3ltuples[0], tuple(true, false, false, 0, 0, -1));
    assertEquals(d3ltuples[1], tuple(false, false, false, 1, 1, -1));
    assertEquals(d3ltuples[2], tuple(false, false, false, -1, 2, -1));
    assertEquals(d3ltuples.length, 3);
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
        while(d.diff1 > 0 && d.diff2 > 0)
        {
            Diff3Line d3l = Diff3Line.init;
            d3l.lineC = lineC;
            diff3LineList.insertBefore(r3, d3l);
            d.diff1--;
            d.diff2--;
            lineA++;
            lineC++;
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

private void updateDiff3LineListUsingBC(DiffList diffList23, ref Diff3LineList diff3LineList)
{
}

Diff3LineList calcDiff3LineList(DiffList diffList12, DiffList diffList13, DiffList diffList23)
{
    Diff3LineList diff3LineList;

    updateDiff3LineListUsingAB(diffList12, diff3LineList);
    updateDiff3LineListUsingAC(diffList13, diff3LineList);
    updateDiff3LineListUsingBC(diffList23, diff3LineList);

    return diff3LineList;
}


