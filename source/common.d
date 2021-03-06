/*
 * tdiff3 - a text-based 3-way diff/merge tool that can handle large files
 * Copyright (C) 2014  Maurice van der Pot <griffon26@kfk4ever.com>
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
 * Authors: Maurice van der Pot
 * License: $(LINK2 http://www.gnu.org/licenses/gpl-2.0.txt, GNU GPL v2.0) or later.
 */
module common;

import std.algorithm;
import std.container;
import std.stdio;
import std.typecons;

import myassert;

class UserException: Exception
{
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

struct Diff
{
    int nofEquals;

    int diff1;
    int diff2;

    this(int eq, int d1, int d2)
    {
        nofEquals = eq;
        diff1 = d1;
        diff2 = d2;
    }
}

alias DiffList = DList!Diff;

enum DiffSelection
{
    A_vs_B,
    A_vs_C,
    B_vs_C
}

enum DiffStyle
{
    DIFFERENT,
    A_B_SAME,
    A_C_SAME,
    B_C_SAME,
    ALL_SAME,
    ALL_SAME_HIGHLIGHTED
}

int left(DiffSelection ds)
{
    final switch(ds)
    {
    case DiffSelection.A_vs_B:
        return 0;
    case DiffSelection.A_vs_C:
        return 0;
    case DiffSelection.B_vs_C:
        return 1;
    }
}

int right(DiffSelection ds)
{
    final switch(ds)
    {
    case DiffSelection.A_vs_B:
        return 1;
    case DiffSelection.A_vs_C:
        return 2;
    case DiffSelection.B_vs_C:
        return 2;
    }
}

struct StyleFragment
{
    DiffStyle style;
    int length;
}

alias StyleList = DList!StyleFragment;

struct Diff3Line
{
    int lineA = -1;
    int lineB = -1;
    int lineC = -1;

    bool bAEqB = false;
    bool bAEqC = false;
    bool bBEqC = false;

    StyleList styleA;
    StyleList styleB;
    StyleList styleC;

    ref int line(int i)
    {
        switch(i)
        {
        case 0:
            return lineA;
        case 1:
            return lineB;
        case 2:
            return lineC;
        default:
            assert(false);
        }
    }

    ref bool equal(DiffSelection diffSel)
    {
        final switch(diffSel)
        {
        case DiffSelection.A_vs_B:
            return bAEqB;
        case DiffSelection.A_vs_C:
            return bAEqC;
        case DiffSelection.B_vs_C:
            return bBEqC;
        }
    }

    ref StyleList style(int i)
    {
        switch(i)
        {
        case 0:
            return styleA;
        case 1:
            return styleB;
        case 2:
            return styleC;
        default:
            assert(false);
        }
    }
}

alias Diff3LineList = DList!Diff3Line;
alias Diff3LineArray = Array!Diff3Line;

template where(T)
{
  T[]   where( T[] arr, bool delegate(T) dg )
  {
    T[] result ;
    foreach( T val; arr ) if ( dg(val) ) result ~= val;
    return result;
  }
}

void log(string msg)
{
    auto f = File("tdiff3.log", "a"); // open for writing
    f.write(msg ~ "\n");
}

immutable trace =`
    import std.string : format;

    import std.traits : ParameterIdentifierTuple;
    mixin(format(
        q{enum args = ParameterIdentifierTuple!(%s);},
        __FUNCTION__
    ));

    import std.algorithm : map, joiner;
    enum args_fmt = [args].map!(a => "%s").joiner(", ");

    mixin(format(
        q{log(format("> %s(%s)", %s));},
        __FUNCTION__,
        args_fmt,
        [args].joiner(", ")
    ));

    scope(exit)
    {
        mixin(format(
           q{log(format("< %s(%s)", %s));},
           __FUNCTION__,
           args_fmt,
           [args].joiner(", ")
        ));
    }
`;

/**
 * A range of line numbers
 */
struct LineNumberRange
{
    /** The first line in the range. -1 can be used to indicate that this range
     * is not valid. A function that calculates overlap between ranges could
     * return this if there is no overlap.
     */
    int firstLine;

    /** The last line in the range. -1 can be used to indicate that this range
     * has no end. Most functions accepting ranges will require the last line
     * to not be -1, so check the preconditions.
     */
    int lastLine;

    bool isFinite()
    {
        return lastLine != -1 && isValid();
    }

    bool isValid()
    {
        return firstLine != -1;
    }
}

/**
 * Checks if the specified line is part of the specified range. The range may be infinite.
 */
bool contains(LineNumberRange range, int line)
{
    assert(range.isValid);

    return line >= range.firstLine && (line <= range.lastLine || !range.isFinite());
}

/**
 * overlap will return the range of lines that is present in both input ranges.
 * The returned range must be checked for validity, because if there is no
 * overlap it will be invalid. The input ranges may be infinite.
 */
LineNumberRange overlap(LineNumberRange thisRange, LineNumberRange otherRange)
{
    assert(thisRange.isValid);
    assert(otherRange.isValid);

    int firstLine = max(thisRange.firstLine, otherRange.firstLine);

    int lastLine;
    if(thisRange.isFinite())
    {
        if(otherRange.isFinite())
        {
            lastLine = min(thisRange.lastLine, otherRange.lastLine);
        }
        else // otherRange is infinite
        {
            lastLine = thisRange.lastLine;
        }
    }
    else // this range is infinite
    {
        // Last is last of other range, regardless of whether that's -1 or not
        lastLine = otherRange.lastLine;
    }

    if((lastLine != -1) && (firstLine > lastLine))
    {
        firstLine = lastLine = -1;
    }

    return LineNumberRange(firstLine, lastLine);
}

unittest
{
    /* First contained in second */
    assertEqual(overlap(LineNumberRange(0, 2), LineNumberRange(0, 5)), LineNumberRange(0, 2));
    assertEqual(overlap(LineNumberRange(2, 5), LineNumberRange(0, 5)), LineNumberRange(2, 5));
    assertEqual(overlap(LineNumberRange(1, 4), LineNumberRange(0, 5)), LineNumberRange(1, 4));

    /* Second contained in first */
    assertEqual(overlap(LineNumberRange(0, 5), LineNumberRange(0, 2)), LineNumberRange(0, 2));
    assertEqual(overlap(LineNumberRange(0, 5), LineNumberRange(2, 5)), LineNumberRange(2, 5));
    assertEqual(overlap(LineNumberRange(0, 5), LineNumberRange(1, 4)), LineNumberRange(1, 4));

    /* Some overlap */
    assertEqual(overlap(LineNumberRange(0, 3), LineNumberRange(2, 5)), LineNumberRange(2, 3));
    assertEqual(overlap(LineNumberRange(0, 3), LineNumberRange(3, 5)), LineNumberRange(3, 3));
    assertEqual(overlap(LineNumberRange(2, 3), LineNumberRange(0, 3)), LineNumberRange(2, 3));
    assertEqual(overlap(LineNumberRange(3, 5), LineNumberRange(0, 3)), LineNumberRange(3, 3));

    /* No overlap */
    assertEqual(overlap(LineNumberRange(0, 2), LineNumberRange(3, 5)), LineNumberRange(-1, -1));
    assertEqual(overlap(LineNumberRange(3, 5), LineNumberRange(0, 2)), LineNumberRange(-1, -1));

    /* First range is infinite, non-infinite overlap */
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(0, 1)), LineNumberRange(-1, -1));
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(0, 2)), LineNumberRange(2, 2));
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(0, 5)), LineNumberRange(2, 5));
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(2, 5)), LineNumberRange(2, 5));
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(4, 5)), LineNumberRange(4, 5));

    /* Second range is infinite, non-infinite overlap */
    assertEqual(overlap(LineNumberRange(0, 1), LineNumberRange(2, -1)), LineNumberRange(-1, -1));
    assertEqual(overlap(LineNumberRange(0, 2), LineNumberRange(2, -1)), LineNumberRange(2, 2));
    assertEqual(overlap(LineNumberRange(0, 5), LineNumberRange(2, -1)), LineNumberRange(2, 5));
    assertEqual(overlap(LineNumberRange(2, 5), LineNumberRange(2, -1)), LineNumberRange(2, 5));
    assertEqual(overlap(LineNumberRange(4, 5), LineNumberRange(2, -1)), LineNumberRange(4, 5));

    /* Infinite overlap */
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(0, -1)), LineNumberRange(2, -1));
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(2, -1)), LineNumberRange(2, -1));
    assertEqual(overlap(LineNumberRange(2, -1), LineNumberRange(5, -1)), LineNumberRange(5, -1));

}

/**
 * merge will return the smallest range that contains both input ranges
 */
LineNumberRange merge(LineNumberRange thisRange, LineNumberRange otherRange)
{
    assert(thisRange.isValid);
    assert(otherRange.isValid);

    return LineNumberRange(min(thisRange.firstLine, otherRange.firstLine),
                           max(thisRange.lastLine, otherRange.lastLine));
}

struct Position
{
    int line;
    int character;

    int opCmp(in Position rhs) const
    {
        return tuple(line, character).opCmp(tuple(rhs.line, rhs.character));
    }
}

