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

import std.algorithm;
import std.array;
import std.c.stddef;
import std.conv;
import std.file;
import std.stdio;
import std.typecons;
import std.utf;

import ilineprovider;

extern (C) int wcwidth(wchar_t c);

int getLengthInColumns(string s)
{
    int nrOfColumns = 0;

    validate(s);


    foreach(dchar c; byDchar(s))
    {
        int width = wcwidth(c);
        if(width != -1)
        {
            nrOfColumns += width;
        }
    }

    return nrOfColumns;
}


synchronized class SimpleFileLineProvider: ILineProvider
{
    private string content;
    private string[] lines;
    private int lastpos;
    private static immutable uint readahead = 100;
    private int m_maxWidth;

    this(string filename)
    {
        content = to!string(read(filename));
        writefln("Done reading file %s", filename);
        ensure_line_is_available(0);
    }

    private void ensure_line_is_available(int index)
    {
        /* index already accessible */
        if(index < lines.length)
        {
            return;
        }

        /* already have indices for all content */
        if(lastpos == content.length)
        {
            return;
        }

        //writeln("ensure ", index);

        int prevlength = to!int(lines.length);
        lines.length = index + readahead + 1;

        int i;
        for(i = prevlength; i < lines.length; i++)
        {
            //writeln("generating line ", i, " from lastpos ", lastpos, " while content.length is ", content.length);
            int eol_offset = to!int(std.string.indexOf(content[lastpos .. $], '\n'));
            if (eol_offset != -1)
            {
                auto endpos = lastpos + eol_offset + 1;
                lines[i] = content[lastpos .. endpos];
                //writefln("    new line content is %s", lines[i]);
                lastpos = endpos;
            }
            else
            {
                lines[i] = content[lastpos .. $];
                //writefln("    new line content is %s", lines[i]);
                lastpos = to!int(content.length);
                break;
            }
            m_maxWidth = max(m_maxWidth, getLengthInColumns(lines[i]));
        }

        /* line storage shouldn't be larger than the number of lines in the content */
        if(lastpos == content.length)
        {
            lines.length = i;
        }
    }

    int getLastLineNumber()
    {
        assert(lastpos == content.length);

        return to!int(lines.length - 1);
    }

    int getMaxWidth()
    {
        return m_maxWidth;
    }

    Nullable!string get(uint i)
    {
        Nullable!string result;
        ensure_line_is_available(i);

        if(i < lines.length)
        {
            result = lines[i];
        }
        else
        {
            result.nullify();
        }

        return result;
    }

    Nullable!string get(uint firstLine, uint lastLine)
    {
        Nullable!string result;
        ensure_line_is_available(lastLine);

        if(firstLine < lines.length)
        {
            auto strBuilder = appender!string;

            for(uint i = firstLine; i <= lastLine; i++)
            {
                if(i >= lines.length)
                {
                    break;
                }
                strBuilder.put(lines[i]);
            }
            result = strBuilder.data;
        }
        else
        {
            result.nullify();
        }

        return result;
    }
}
