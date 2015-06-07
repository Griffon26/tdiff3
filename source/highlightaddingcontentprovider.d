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

import std.algorithm;
import std.conv;
import std.signals;
import std.string;
import std.typecons;

import common;
import iformattedcontentprovider;

/**
 * HighlightAddingContentProvider is an IFormattedContentProvider that
 * highlights a selected range of lines. This applies some additional
 * formatting on top of another IFormattedContentProvider and is used
 * for highlighting the selected section in both the input and the output
 * panes.
 */
class HighlightAddingContentProvider: IFormattedContentProvider
{
private:
    IFormattedContentProvider m_originalContentProvider;
    LineNumberRange m_linesToHighlight;
    int m_lastRequestedLine;
    int m_lastLineLength;

    mixin Signal!(LineNumberRange) m_linesChanged;

public:
    this(IFormattedContentProvider originalContentProvider)
    {
        m_originalContentProvider = originalContentProvider;
        m_linesToHighlight.firstLine = 0;
        m_linesToHighlight.lastLine = 0;

        m_originalContentProvider.connectLineChangeObserver(&linesChanged);

        m_lastRequestedLine = -1;
    }

    void setHighlight(LineNumberRange linesToHighlight)
    {
        auto rangeToRedraw = merge(linesToHighlight, m_linesToHighlight);
        m_linesToHighlight = linesToHighlight;
        m_linesChanged.emit(rangeToRedraw);
    }

    Nullable!string get(int line)
    {
        auto originalLine = m_originalContentProvider.get(line);
        string text;

        if(originalLine.isNull())
        {
            text = "\n";
        }
        else
        {
            text = originalLine.get();
        }

        m_lastRequestedLine = line;
        m_lastLineLength = to!int(text.length);

        if(m_linesToHighlight.contains(line))
        {
            int padding = to!int(m_originalContentProvider.getContentWidth() - text.lengthInColumns(true));

            log(format("lastLinePadding for line %d was %d", line, padding));

            char[] restOfLine;
            restOfLine.length = padding;
            restOfLine[] = ' ';

            m_lastLineLength += padding;

            string result = (text[0..$-1] ~ restOfLine ~ text[$-1..$]).idup;
            //string result = text;
            originalLine = result;
        }

        return originalLine;
    }

    StyleList getFormat(int line)
    {
        assert(line == m_lastRequestedLine);

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
            styleList.insertBack(StyleFragment(DiffStyle.ALL_SAME_HIGHLIGHTED, m_lastLineLength - styleLength));
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

    void connectLineChangeObserver(void delegate(LineNumberRange lines) d)
    {
        /* TODO: make sure to register for line changes at the content mapper */
        m_linesChanged.connect(d);
    }

    void linesChanged(LineNumberRange lines)
    {
        /* TODO: implement */
    }
}

