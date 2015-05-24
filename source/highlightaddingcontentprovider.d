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
module highlightaddingcontentprovider;

import std.typecons;

import common;
import iformattedcontentprovider;

/**
 * 
 */
class HighlightAddingContentProvider: IFormattedContentProvider
{
private:
    IFormattedContentProvider m_originalContentProvider;
    LineNumberRange m_linesToHighlight;

public:
    this(IFormattedContentProvider originalContentProvider)
    {
        m_originalContentProvider = originalContentProvider;
    }

    void setHighlight(LineNumberRange linesToHighlight)
    {
        m_linesToHighlight = linesToHighlight;
    }

    Nullable!string get(int line)
    {
        return m_originalContentProvider.get(line);
    }

    StyleList getFormat(int line)
    {
        if(m_linesToHighlight.contains(line))
        {
            /* TODO: return different formatting for this line */
            return m_originalContentProvider.getFormat(line);
        }
        else
        {
            return m_originalContentProvider.getFormat(line);
        }
    }

    int getContentWidth()
    {
        return m_originalContentProvider.getContentWidth();
    }

    int getContentHeight()
    {
        return m_originalContentProvider.getContentHeight();
    }
}

