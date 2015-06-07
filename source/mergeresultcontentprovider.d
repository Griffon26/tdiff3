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
module mergeresultcontentprovider;

import std.algorithm;
import std.container;
import std.container.util;
import std.conv;
import std.signals;
import std.string;
import std.typecons;

import common;
import contentmapper;
import iformattedcontentprovider;
import ilineprovider;
import myassert;

/**
 * MergeResultContentProvider is provides a view on the content from an
 * ILineProvider plus modifications. It asks ContentMapper where it can find
 * each line and then either gets the edited line from the ContentMapper or the
 * unmodified line from one of the ILineProviders.
 */
class MergeResultContentProvider: IFormattedContentProvider
{
private:
    ContentMapper m_contentMapper;
    shared ILineProvider[3] m_lps;
    DList!MergeResultSection m_mergeResultSections;

    mixin Signal!(LineNumberRange) m_lineChanged;

public:
    this(ContentMapper contentMapper,
         shared ILineProvider lps0,
         shared ILineProvider lps1,
         shared ILineProvider lps2)
    {
        m_contentMapper = contentMapper;
        m_lps[0] = lps0;
        m_lps[1] = lps1;
        m_lps[2] = lps2;
    }

    /* IFormattedContentProvider methods */

    Nullable!string get(int line)
    {
        Nullable!string result;
        auto lineInfo = m_contentMapper.getMergeResultLineInfo(line);

        final switch(lineInfo.state)
        {
        case LineState.EDITED:
            result = m_contentMapper.getEditedLine(lineInfo.sectionIndex, lineInfo.lineNumber);
            break;
        case LineState.NONE:
            result = "<unresolved conflict>\n";
            break;
        case LineState.ORIGINAL:
            if(lineInfo.lineNumber == -1)
            {
                result = "<no source line>\n";
            }
            else
            {
                result = m_lps[lineInfo.source].get(lineInfo.lineNumber);
            }
            break;
        }
        return result;
    }

    StyleList getFormat(int line)
    {
        return make!StyleList;
    }

    int getContentWidth()
    {
        /* TODO: implement */
        return 1000;
    }

    int getContentHeight()
    {
        return m_contentMapper.getContentHeight();
    }

    void connectLineChangeObserver(void delegate(LineNumberRange lines) d)
    {
        /* TODO: make sure to register for line changes at the content mapper */
        m_lineChanged.connect(d);
    }
}


