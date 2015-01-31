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

import std.c.locale;
import std.c.stddef;
import std.container;
import std.utf;

import myassert;

extern (C) int wcwidth(wchar_t c);

int lengthInColumns(string s)
{
    int nrOfColumns = 0;

    validate(s);

    foreach(dchar c; byDchar(s))
    {
        auto width = (c == '\n') ? 1 : wcwidth(c);
        if(width != -1)
        {
            nrOfColumns += width;
        }
    }

    return nrOfColumns;
}

string substringColumns(string s, int startColumn, int endColumn)
{
    size_t startIndex;
    int columnsToSkip = startColumn;
    while(columnsToSkip > 0)
    {
        dchar c = decode(s, startIndex);
        auto width = (c == '\n') ? 1 : wcwidth(c);
        if(width != -1)
        {
            columnsToSkip -= width;
        }
    }
    // TODO: fix this for chars that need multiple columns
    assert(columnsToSkip == 0);

    size_t endIndex = startIndex;
    columnsToSkip = endColumn - startColumn;
    while(columnsToSkip > 0)
    {
        size_t prevIndex = endIndex;
        dchar c = decode(s, endIndex);
        auto width = (c == '\n') ? 1 : wcwidth(c);
        if(width != -1)
        {
            columnsToSkip -= width;
        }
    }
    // TODO: fix this for chars that need multiple columns
    assert(columnsToSkip == 0);

    return s[startIndex..endIndex];
}

unittest
{

    string one_byte_one_column = "a";
    //dchar one_byte_two_columns = '';
    string two_bytes_one_column = "é";
    //dchar two_bytes_two_columns = '';
    string three_bytes_one_column = "€";
    string three_bytes_two_columns = "\uFF04";   // full-width dollar sign
    //dchar four_bytes_one_column = '';
    string four_bytes_two_columns = "\U00020000";    // CJK ...

    setlocale(LC_ALL, "");

    assertEqual(substringColumns("." ~ one_byte_one_column ~ ".", 1, 2), one_byte_one_column);
    assertEqual(substringColumns("." ~ two_bytes_one_column ~ ".", 1, 2), two_bytes_one_column);
    assertEqual(substringColumns("." ~ three_bytes_one_column ~ ".", 1, 2), three_bytes_one_column);

    assertEqual(substringColumns("." ~ three_bytes_two_columns ~ ".", 1, 3), three_bytes_two_columns);
    assertEqual(substringColumns("." ~ four_bytes_two_columns ~ ".", 1, 3), four_bytes_two_columns);

    assertEqual(substringColumns("." ~ one_byte_one_column ~ "a.", 2, 3), "a");
    assertEqual(substringColumns("." ~ two_bytes_one_column ~ "a.", 2, 3), "a");
    assertEqual(substringColumns("." ~ three_bytes_one_column ~ "a.", 2, 3), "a");

    assertEqual(substringColumns("." ~ three_bytes_two_columns ~ "a.", 3, 4), "a");
    assertEqual(substringColumns("." ~ four_bytes_two_columns ~ "a.", 3, 4), "a");
}

struct Diff
{
    uint nofEquals;

    uint diff1;
    uint diff2;

    this(uint eq, uint d1, uint d2)
    {
        nofEquals = eq;
        diff1 = d1;
        diff2 = d2;
    }
}

alias DiffList = DList!Diff;

struct Diff3Line
{
    int lineA = -1;
    int lineB = -1;
    int lineC = -1;

    bool bAEqB = false;
    bool bAEqC = false;
    bool bBEqC = false;

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

    ref bool equal(int i)
    {
        switch(i)
        {
        case 0:
            return bAEqB;
        case 1:
            return bAEqC;
        case 2:
            return bBEqC;
        default:
            assert(false);
        }
    }
}

alias Diff3LineList = DList!Diff3Line;
alias Diff3LineArray = Array!Diff3Line;

