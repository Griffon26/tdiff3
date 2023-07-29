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
#pragma once

#include <cassert>
#include <string>
#include <vector>

class UserException: public std::exception
{
};

struct Diff
{
    Diff(int eq, int d1, int d2):
        nofEquals(eq),
        diff1(d1),
        diff2(d2)
    {
    }

    int nofEquals;

    int diff1;
    int diff2;
};

using DiffList = std::vector<Diff>;

enum class DiffSelection
{
    A_vs_B,
    A_vs_C,
    B_vs_C
};

enum class DiffStyle
{
    DIFFERENT,
    A_B_SAME,
    A_C_SAME,
    B_C_SAME,
    ALL_SAME,
    ALL_SAME_HIGHLIGHTED
};

int left(DiffSelection ds);
int right(DiffSelection ds);

struct StyleFragment
{
    DiffStyle style;
    int length;
};

using StyleList = std::vector<StyleFragment>;

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

    int& line(int i)
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

    bool& equal(DiffSelection diffSel)
    {
        switch(diffSel)
        {
        case DiffSelection::A_vs_B:
            return bAEqB;
        case DiffSelection::A_vs_C:
            return bAEqC;
        case DiffSelection::B_vs_C:
            return bBEqC;
        }
    }

    StyleList& style(int i)
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
};

using Diff3LineList = std::vector<Diff3Line>;
//using Diff3LineArray = std::array<Diff3Line>;

#if 0
template where(T)
{
  T[]   where( T[] arr, bool delegate(T) dg )
  {
    T[] result ;
    foreach( T val; arr ) if ( dg(val) ) result ~= val;
    return result;
  }
}
#endif

void log(std::string msg);

/**
 * A range of line numbers
 */
struct LineNumberRange
{
    LineNumberRange(int first, int last):
        firstLine(first),
        lastLine(last)
    {
    }

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

    bool operator==(const LineNumberRange& other) const
    {
        return firstLine == other.firstLine && lastLine == other.lastLine;
    }
};

/**
 * Checks if the specified line is part of the specified range. The range may be infinite.
 */
bool contains(LineNumberRange range, int line);

/**
 * overlap will return the range of lines that is present in both input ranges.
 * The returned range must be checked for validity, because if there is no
 * overlap it will be invalid. The input ranges may be infinite.
 */
LineNumberRange overlap(LineNumberRange thisRange, LineNumberRange otherRange);

/**
 * merge will return the smallest range that contains both input ranges
 */
LineNumberRange merge(LineNumberRange thisRange, LineNumberRange otherRange);

struct Position
{
    int line;
    int character;

#ifdef TODO
    int opCmp(in Position rhs) const
    {
        return tuple(line, character).opCmp(tuple(rhs.line, rhs.character));
    }
#endif
};

