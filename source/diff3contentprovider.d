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

import std.typecons;

import common;
import icontentprovider;
import ilineprovider;

class Diff3ContentProvider: IContentProvider
{
    int m_contentWidth;
    int m_contentHeight;
    Diff3LineArray m_d3la;
    int m_fileIndex;
    shared ILineProvider m_lp;

    this(int contentWidth, int contentHeight, Diff3LineArray d3la, int fileIndex, shared ILineProvider lp)
    {
        m_contentWidth = contentWidth;
        m_contentHeight = contentHeight;
        m_d3la = d3la;
        m_fileIndex = fileIndex;
        m_lp = lp;
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
            result = m_lp.get(fileLine);
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

}
