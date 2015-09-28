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
module myassert;

import std.algorithm;
import std.conv;
import std.range;
import std.string;

import dunit;

void assertEqual(T, U)(T actual, U expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    assertEquals(expected, actual, msg, file, line);
}

void assertArraysEqual(T, U)(T[] actual, U[] expected, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    auto actualstring = actual.map!(el => "  " ~ to!string(el)).join("\n");
    auto expectedstring = expected.map!(el => "  " ~ to!string(el)).join("\n");

    if(actual.length != expected.length)
    {
        auto message = format("Arrays differ.\nexpected:\n%s\nbut was:\n%s\nArrays are not the same length", expectedstring, actualstring);
        assertEquals(expected.length, actual.length, message, file, line);
    }

    foreach(i, act, exp; enumerate(zip(actual, expected)))
    {
        if(act != exp)
        {
            auto message = format("Arrays differ.\nexpected:\n%s\nbut was:\n%s\nMismatch starting at index %d", expectedstring, actualstring, i);
            assertEquals(exp, act, message, file, line);
            break;
        }
    }
}
