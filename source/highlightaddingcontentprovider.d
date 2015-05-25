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
        m_linesToHighlight.firstLine = 3;
        m_linesToHighlight.lastLine = 7;
    }

    void setHighlight(LineNumberRange linesToHighlight)
    {
        m_linesToHighlight = linesToHighlight;
    }

    Nullable!string get(int line)
    {
        auto originalLine = m_originalContentProvider.get(line);

        if(m_linesToHighlight.contains(line))
        {
            string text;

            if(originalLine.isNull())
            {
                text = "\n";
            }
            else
            {
                text = originalLine.get();
            }

            char[] restOfLine;
            restOfLine.length = m_originalContentProvider.getContentWidth() - text.length;
            restOfLine[] = ' ';

            string result = (text[0..$-1] ~ restOfLine ~ text[$-1..$]).idup;
            //string result = text;
            originalLine = result;
        }

        return originalLine;
    }

    StyleList getFormat(int line)
    {
        StyleList styleList = m_originalContentProvider.getFormat(line);
        if(m_linesToHighlight.contains(line))
        {
            int styleLength = 0;
            foreach(ref styleFragment; styleList)
            {
                styleLength += styleFragment.length;
                if(styleFragment.style == DiffStyle.ALL_SAME)
                {
                    styleFragment.style = DiffStyle.ALL_SAME_HIGHLIGHTED;
                }
            }
            styleList.insertBack(StyleFragment(DiffStyle.ALL_SAME_HIGHLIGHTED, getContentWidth() - styleLength));
        }
        return styleList;
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

