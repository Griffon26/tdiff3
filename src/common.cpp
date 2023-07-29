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

#include <cassert>
#include <fstream>
#include <string>
#include <vector>

#include "common.h"

int left(DiffSelection ds)
{
    switch(ds)
    {
    case DiffSelection::A_vs_B:
        return 0;
    case DiffSelection::A_vs_C:
        return 0;
    case DiffSelection::B_vs_C:
        return 1;
    }
}

int right(DiffSelection ds)
{
    switch(ds)
    {
    case DiffSelection::A_vs_B:
        return 1;
    case DiffSelection::A_vs_C:
        return 2;
    case DiffSelection::B_vs_C:
        return 2;
    }
}

void log(std::string msg)
{
    std::fstream f;
    f.open("tdiff3.log", std::ios_base::out|std::ios_base::app); // open for writing
    f << msg << "\n";
    f.close();
}

/**
 * Checks if the specified line is part of the specified range. The range may be infinite.
 */
bool contains(LineNumberRange range, int line)
{
    assert(range.isValid());

    return line >= range.firstLine && (line <= range.lastLine || !range.isFinite());
}

/**
 * overlap will return the range of lines that is present in both input ranges.
 * The returned range must be checked for validity, because if there is no
 * overlap it will be invalid. The input ranges may be infinite.
 */
LineNumberRange overlap(LineNumberRange thisRange, LineNumberRange otherRange)
{
    assert(thisRange.isValid());
    assert(otherRange.isValid());

    int firstLine = std::max(thisRange.firstLine, otherRange.firstLine);

    int lastLine;
    if(thisRange.isFinite())
    {
        if(otherRange.isFinite())
        {
            lastLine = std::min(thisRange.lastLine, otherRange.lastLine);
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

/**
 * merge will return the smallest range that contains both input ranges
 */
LineNumberRange merge(LineNumberRange thisRange, LineNumberRange otherRange)
{
    assert(thisRange.isValid());
    assert(otherRange.isValid());

    return LineNumberRange(std::min(thisRange.firstLine, otherRange.firstLine),
                           std::max(thisRange.lastLine, otherRange.lastLine));
}


