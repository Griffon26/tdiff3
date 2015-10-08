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
module stringcolumns;

import std.c.locale;
import std.c.stddef;
import std.container;
import std.conv;
import std.utf;

import myassert;
import unittestdata;

extern (C) int wcwidth(wchar_t c);

private int customWcWidth(wchar_t c, bool acceptUnprintable)
{
    auto width = (c == '\n') ? 1 : wcwidth(c);
    if(width == -1)
    {
        if(acceptUnprintable)
        {
            width = 1;
        }
        else
        {
            // TODO
            assert(false);
        }
    }
    return width;
}

/**
 * Like customWcWidth, but also calculate the width of tab characters based on
 * the specified offset to the next tabstop.
 */
private int customWcWidthWithTabs(wchar_t c, int tabStopOffset, bool acceptUnprintable)
{
    assert(tabStopOffset >= 0);
    assert(tabStopOffset <= 7);

    if(c == '\t')
    {
        return (tabStopOffset == 0) ? 8 : tabStopOffset;
    }
    else
    {
        return customWcWidth(c, acceptUnprintable);
    }
}

/**
 * The CharInfo class provides the byte position in the string and the column
 * on the screen for a character and a way to navigate to the next/previous
 * character or the first character in the next/previous column.
 */
class CharInfo
{
public:
    /**
     * The byte position of this character in the string. Because characters
     * (or rather code points) take up a varying number of bytes in utf-8, the
     * n'th character is often not at the n'th byte position in the string
     */
    size_t index;

    /**
     * The column of the screen corresponding to the start of the character.
     * For characters that have no width, the column of the character after
     * this one will be the same. For characters that have a width > 1, this is
     * the first column occupied by this character
     */
    int column;

    /**
     * The previous character, or null if this character is the first one in
     * the string
     */
    CharInfo prevChar;
    /**
     * The next character, or null if this character is the last one in the
     * string
     */
    CharInfo nextChar;

    /**
     * The first character in the previous column, or null if this character is
     * already in the first column for the string
     */
    CharInfo prevColumn;
    /**
     * The first character in the next column, or null if this character is
     * already in the last column for this string
     */
    CharInfo nextColumn;

    this(size_t index, int column)
    {
        this.index = index;
        this.column = column;
    }
}

/**
 * The StringColumns class makes it easy to navigate through a unicode string
 * either by character or by the columns they occupy on the screen. For each
 * character navigated to, the index in the unicode string as well as the column
 * on the screen can be retrieved.
 */
class StringColumns
{
private:
    DList!CharInfo m_chars;
    CharInfo m_currentChar;
    int m_nrOfColumns;

public:
    /**
     * Constructor that creates a doubly linked list of CharInfo objects.
     * 
     * Params:
     *   s      = the string to parse into a list of CharInfo objects
     *   column = the column position of interest. After construction
     *            currentChar will return the CharInfo corresponding to the
     *            first character in the specified column. Consider specifying
     *            this instead of iterating over the CharInfo list to find a
     *            character at a specific position, because it will avoid an
     *            additional iteration.
     */
    this(string s, int column)
    {
        auto tabStopOffset = 0;

        size_t currentIndex = 0;
        int currentColumn = 0;

        CharInfo prevChar;
        CharInfo prevColumn;

        bool firstCharInString = true;

        while(currentIndex < s.length)
        {
            auto nextIndex = currentIndex;
            dchar c = decode(s, nextIndex);
            auto width = customWcWidthWithTabs(c, tabStopOffset, true);
            assert(width != -1);

            CharInfo charInfo = new CharInfo(currentIndex, currentColumn);
            m_chars.insertBack(charInfo);
            charInfo.prevChar = prevChar;
            charInfo.prevColumn = prevColumn;

            if((firstCharInString || width > 0) && currentColumn <= column)
            {
                m_currentChar = charInfo;
                firstCharInString = false;
            }

            if(prevChar !is null)
            {
                prevChar.nextChar = charInfo;
            }
            prevChar = charInfo;

            if(width > 0)
            {
                if(prevColumn !is null)
                {
                    CharInfo ci = prevColumn;
                    while(ci !is charInfo)
                    {
                        ci.nextColumn = charInfo;
                        ci = ci.nextChar;
                    }
                }
                prevColumn = charInfo;
            }

            currentColumn += width;
            currentIndex = nextIndex;
            assert(width <= 8);
            tabStopOffset = (8 + tabStopOffset - width) % 8;
        }
        m_nrOfColumns = currentColumn;
    }

    version(unittest)
    {
        string toColumnIndices()
        {
            string text;
            auto charInfo = m_chars.front;
            while(charInfo)
            {
                text ~= (charInfo.prevColumn is null) ? "." : "-";
                text ~= to!string(charInfo.index);
                text ~= (charInfo.nextColumn is null) ? "." : "-";
                charInfo = charInfo.nextColumn;
            }
            return text;
        }

        string toColumns()
        {
            string text;
            auto charInfo = m_chars.front;
            while(charInfo)
            {
                text ~= (charInfo.prevColumn is null) ? "." : "-";
                text ~= to!string(charInfo.column);
                text ~= (charInfo.nextColumn is null) ? "." : "-";
                charInfo = charInfo.nextColumn;
            }
            return text;
        }

        string toIndices()
        {
            string text;
            auto charInfo = m_chars.front;
            while(charInfo)
            {
                text ~= (charInfo.prevChar is null) ? "." : "-";
                text ~= to!string(charInfo.index);
                text ~= (charInfo.nextChar is null) ? "." : "-";
                charInfo = charInfo.nextChar;
            }
            return text;
        }

        string[] toColumnsAndIndices()
        {
            return [toColumns(), toIndices()];
        }

        int getCharIndexOfCurrent()
        {
            int index = 0;
            auto charInfo = m_chars.front;
            while(charInfo !is m_currentChar)
            {
                charInfo = charInfo.nextChar;
                assert(charInfo !is null);
                index++;
            }
            return index;
        }
    }

    unittest
    {
        setlocale(LC_ALL, "");

        /* Test if strings with characters of various sequences of bytes and varying widths are converted into the correct CharInfo chains */
        assertEqual(new StringColumns("123", 0).toColumnsAndIndices,  [".0--1--2.", ".0--1--2."]);
        assertEqual(new StringColumns("\t89", 0).toColumnsAndIndices, [".0--8--9.", ".0--1--2."]);
        assertEqual(new StringColumns("0\t8", 0).toColumnsAndIndices, [".0--1--8.", ".0--1--2."]);
        assertEqual(new StringColumns("0123456\t8", 0).toColumnsAndIndices, [".0--1--2--3--4--5--6--7--8.", ".0--1--2--3--4--5--6--7--8."]);
        assertEqual(new StringColumns("01234567\tx", 0).toColumnsAndIndices, [".0--1--2--3--4--5--6--7--8--16.", ".0--1--2--3--4--5--6--7--8--9."]);
        assertEqual(new StringColumns("\t\tx", 0).toColumnsAndIndices, [".0--8--16.", ".0--1--2."]);
        assertEqual(new StringColumns("0\t8\tx", 0).toColumnsAndIndices, [".0--1--8--9--16.", ".0--1--2--3--4."]);

        assertEqual(new StringColumns(two_bytes_one_column ~ "x", 0).toColumnsAndIndices, [".0--1.", ".0--2."]);
        assertEqual(new StringColumns(two_bytes_one_column ~ two_bytes_one_column ~ "\tx", 0).toColumnsAndIndices, [".0--1--2--8.", ".0--2--4--5."]);
        assertEqual(new StringColumns(three_bytes_one_column ~ "x", 0).toColumnsAndIndices, [".0--1.", ".0--3."]);
        assertEqual(new StringColumns(three_bytes_two_columns ~ "x", 0).toColumnsAndIndices, [".0--2.", ".0--3."]);
        assertEqual(new StringColumns(four_bytes_two_columns ~ "x", 0).toColumnsAndIndices, [".0--2.", ".0--4."]);
        assertEqual(new StringColumns(four_bytes_unprintable ~ "x", 0).toColumnsAndIndices, [".0--1.", ".0--4."]);

        assertEqual(new StringColumns("a" ~ two_bytes_zero_columns ~ "b", 0).toColumnsAndIndices, [".0--1.", ".0--1--3."]);
        assertEqual(new StringColumns("a" ~ two_bytes_zero_columns ~ "b", 0).toColumnIndices, ".0--3.");

    }

    unittest
    {
        setlocale(LC_ALL, "");

        /* Test various initial columns and how they are mapped to the character they are in */
        assertEqual(new StringColumns("abc", 1).getCharIndexOfCurrent, 1);
        assertEqual(new StringColumns("\tbc", 1).getCharIndexOfCurrent, 0);
        assertEqual(new StringColumns("a\tc", 1).getCharIndexOfCurrent, 1);
        assertEqual(new StringColumns("a\tc", 2).getCharIndexOfCurrent, 1);

        assertEqual(new StringColumns("e" ~ two_bytes_zero_columns ~ "x", 1).getCharIndexOfCurrent, 2);
        assertEqual(new StringColumns(three_bytes_two_columns ~ "x", 0).getCharIndexOfCurrent, 0);
        assertEqual(new StringColumns(three_bytes_two_columns ~ "x", 1).getCharIndexOfCurrent, 0);
        assertEqual(new StringColumns(three_bytes_two_columns ~ "x", 2).getCharIndexOfCurrent, 1);
        assertEqual(new StringColumns(four_bytes_two_columns ~ "x", 1).getCharIndexOfCurrent, 0);
        assertEqual(new StringColumns(four_bytes_unprintable ~ "x", 0).getCharIndexOfCurrent, 0);
        assertEqual(new StringColumns(four_bytes_unprintable ~ "x", 1).getCharIndexOfCurrent, 1);

        /* Test initial column beyond the end of the string */
        assertEqual(new StringColumns("abc", 5).getCharIndexOfCurrent, 2);
        assertEqual(new StringColumns("ab\t", 10).getCharIndexOfCurrent, 2);
        assertEqual(new StringColumns(three_bytes_two_columns, 5).getCharIndexOfCurrent, 0);
        assertEqual(new StringColumns(four_bytes_unprintable ~ four_bytes_unprintable, 2).getCharIndexOfCurrent, 1);

    }

    unittest
    {
        setlocale(LC_ALL, "");

        assertEqual(new StringColumns("abc", 0).m_nrOfColumns, 3);
        assertEqual(new StringColumns("\tbc", 0).m_nrOfColumns, 10);
        assertEqual(new StringColumns("a\tc", 0).m_nrOfColumns, 9);
        assertEqual(new StringColumns("a" ~ two_bytes_zero_columns ~ "b", 0).m_nrOfColumns, 2);
    }

    /**
     * The CharInfo for the first character in the column passed to the constructor
     */
    auto currentChar()
    {
        return m_currentChar;
    }

    /**
     * The CharInfo for the last character in the string
     */
    auto lastChar()
    {
        return m_chars.back();
    }

    /**
     * The number of columns occupied by all characters in the string
     */
    auto lengthInColumns()
    {
        return m_nrOfColumns;
    }
}

/**
 * A convenience function that constructs a StringColumns instance. Thanks to
 * UFCS it can be called like a method on a string.
 *
 * Params:
 *   s      = the string to parse into a list of CharInfo objects
 *   column = the column position of interest. If the StringColumns instance is
 *   to be used to request information or navigate from a character at a
 *   certain column position, then specifying this position in this function
 *   avoids having to iterate over the string a second time later.
 */
auto toStringColumns(string s, int column)
{
    return new StringColumns(s, column);
}


