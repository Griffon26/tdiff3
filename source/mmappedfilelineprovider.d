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
module mmappedfilelineprovider;

import core.stdc.string;

import std.algorithm;
import std.conv;
import std.mmfile;
import std.range;
import std.stdio;
import std.typecons;

import ilineprovider;

/**
 * This is a temporary implementation of a line provider that reads lines from a file.
 * It caches the positions of line endings to avoid having to parse the entire
 * file again and again.
 * As the name says the implementation is very simple and just reads the entire
 * file into memory first. This implementation will have to be replaced by one
 * that limits the amount of memory it uses (either by caching part of the file
 * or by using mmap).
 */
class MmappedFileLineProvider: ILineProvider
{
private:
    static immutable int readahead = 10000;
    int m_maxWidth;
    ulong[] m_lineEnds;
    MmFile m_file;
    ulong m_fileLength;
    string m_filename;

public:
    this(string filename)
    {
        //m_file = new MmFile(filename);
        m_file = new MmFile(filename, MmFile.Mode.read, 0, null, 0);
        m_fileLength = m_file.length;
        m_filename = filename;
    }

    private void ensure_line_is_available(int index)
    {
        /* index already accessible */
        if(index < m_lineEnds.length)
        {
            return;
        }

        //writefln("%s: ensure %d", m_filename, index);

        auto lastpos = (m_lineEnds.length == 0) ? 0 : m_lineEnds[$ - 1];

        /* already have indices for all content */
        if(lastpos == m_fileLength)
        {
            return;
        }

        //writeln("ensure ", index);

        int prevlength = to!int(m_lineEnds.length);
        m_lineEnds.length = index + readahead + 1;

        int i;
        auto restOfFile = cast(ubyte[])(m_file[lastpos .. m_fileLength]);
        ubyte *pStart = &restOfFile[0];
        for(i = prevlength; i < m_lineEnds.length; i++)
        {
            //writeln(m_filename, ": generating line ", i, " starting at lastpos ", lastpos);
            ubyte *pNewLine = cast(ubyte *)memchr(pStart, '\n', restOfFile.length);
            ulong lineLength = (pNewLine == null) ? restOfFile.length : pNewLine - pStart + 1;
            lastpos = lastpos + lineLength;

            m_lineEnds[i] = lastpos;

            if(lineLength > m_maxWidth)
            {
                m_maxWidth = to!int(lineLength);
            }

            //writefln("Line %d is %s", i, m_file[lineStart..m_lineEnds[i]]);

            /* line storage shouldn't be larger than the number of lines in the content */
            if(lastpos == m_fileLength)
            {
                m_lineEnds.length = i + 1;
                break;
            }

            pStart = pNewLine + 1;
        }

        //writefln("%s: m_filename: lastpos is %d, file length is %d, number of lines is %d", m_filename, lastpos, m_fileLength, m_lineEnds.length);
    }

    int getLastLineNumber()
    {
        assert(m_lineEnds[$ - 1] == m_fileLength);

        return to!int(m_lineEnds.length - 1);
    }

    int getMaxWidth()
    {
        return m_maxWidth;
    }

    Tuple!(int, "count", string, "text") get(int i)
    {
        Tuple!(int, "count", string, "text") result;
        ensure_line_is_available(i);

        if(i < m_lineEnds.length)
        {
            auto lineStart = (i == 0) ? 0 : m_lineEnds[i - 1];
            auto lineEnd = m_lineEnds[i];
            result.text = to!string(m_file[lineStart..lineEnd]);
            result.count = 1;
        }
        else
        {
            result.text = "";
            result.count = 0;
        }

        return result;
    }

    Tuple!(int, "count", string, "text") get(int firstLine, int lastLine)
    {
        Tuple!(int, "count", string, "text") result;
        ensure_line_is_available(lastLine);

        if(firstLine < m_lineEnds.length)
        {
            auto lineStart = (firstLine == 0) ? 0 : m_lineEnds[firstLine - 1];
            if(lastLine > m_lineEnds.length - 1)
            {
                lastLine = to!int(m_lineEnds.length) - 1;
            }
            auto lineEnd = m_lineEnds[lastLine];
            result.count = lastLine - firstLine + 1;
            result.text = to!string(m_file[lineStart..lineEnd]);
        }
        else
        {
            result.text = "";
            result.count = 0;
        }

        return result;
    }
}


