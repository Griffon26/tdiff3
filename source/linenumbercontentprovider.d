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
module linenumbercontentprovider;

import std.typecons;
import std.string;

import common;
import icontentprovider;

/**
 * LineNumberContentProvider is a simple content provider that provides line
 * numbers to match the lines in a Diff3LineArray belonging to one of the input
 * files. Which input file it will provide line numbers for is chosen when
 * the LineNumberContentProvider is created.
 */
class LineNumberContentProvider: IContentProvider
{
    int m_contentWidth;
    int m_contentHeight;
    Diff3LineArray m_d3la;
    int m_fileIndex;

    this(int contentWidth, int contentHeight, Diff3LineArray d3la, int fileIndex)
    {
        m_contentWidth = contentWidth;
        m_contentHeight = contentHeight;
        m_d3la = d3la;
        m_fileIndex = fileIndex;
    }

    Nullable!string get(int contentLine)
    {
        Nullable!string result;

        assert(contentLine < m_contentHeight);

        int fileLine = m_d3la[contentLine].line(m_fileIndex);

        if(fileLine == -1)
        {
            result.nullify();
        }
        else
        {
            result = format("%0*d", m_contentWidth, fileLine);
        }
        return result;
    }

    int getContentWidth()
    {
        return m_contentWidth;
    }

    int getContentHeight()
    {
        return m_contentHeight;
    }

    void connectLineChangeObserver(void delegate(LineNumberRange lines) d)
    {
        /* no need to do anything for content that doesn't change */
    }
}

