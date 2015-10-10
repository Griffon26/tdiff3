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
import std.stdio;
import std.string;
import std.typecons;

import common;
import contentmapper;
import iformattedcontentprovider;
import ilineprovider;
import myassert;

enum LineType
{
    UNRESOLVED_CONFLICT,
    NO_SOURCE_LINE,
    NORMAL,
    NONE
}

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
    ILineProvider[3] m_lps;
    DList!MergeResultSection m_mergeResultSections;
    string m_outputFileName;

public:
    this(ContentMapper contentMapper,
         ILineProvider lps0,
         ILineProvider lps1,
         ILineProvider lps2,
         string outputFileName)
    {
        m_contentMapper = contentMapper;
        m_lps[0] = lps0;
        m_lps[1] = lps1;
        m_lps[2] = lps2;
        m_outputFileName = outputFileName;
    }

    /* IFormattedContentProvider methods */

    Tuple!(LineType, "type", string, "text") getLineWithType(int lineNumber)
    {
        string text = "\n";
        LineType lineType;

        auto lineInfo = m_contentMapper.getMergeResultLineInfo(lineNumber);

        final switch(lineInfo.state)
        {
        case LineState.EDITED:
            if(lineInfo.lineNumber == -1)
            {
                lineType = LineType.NO_SOURCE_LINE;
            }
            else
            {
                text = m_contentMapper.getEditedLine(lineInfo.sectionIndex, lineInfo.lineNumber);
                lineType = LineType.NORMAL;
            }
            break;
        case LineState.UNSELECTED:
            lineType = LineType.UNRESOLVED_CONFLICT;

            break;
        case LineState.ORIGINAL:
            if(lineInfo.lineNumber == -1)
            {
                lineType = LineType.NO_SOURCE_LINE;
            }
            else
            {
                auto result = m_lps[lineInfo.source].get(lineInfo.lineNumber);

                /* this should always be a valid line, otherwise contentmapper
                 * shouldn't have given us a valid line number and a source */
                assert(result.count != 0);

                lineType = LineType.NORMAL;
                text = result.text;
            }
            break;
        case LineState.NONE:
            lineType = LineType.NONE;
            break;
        }
        return tuple!("type", "text")(lineType, text);
    }

    Nullable!string get(int lineNumber)
    {
        Nullable!string result;

        auto line = getLineWithType(lineNumber);

        final switch(line.type)
        {
        case LineType.NORMAL:
            result = line.text;
            break;
        case LineType.UNRESOLVED_CONFLICT:
            result = "<unresolved conflict>\n";
            break;
        case LineType.NO_SOURCE_LINE:
            result = "<no source line>\n";
            break;
        case LineType.NONE:
            result.nullify();
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
        m_contentMapper.connectLineChangeObserver(d);
    }

    void save()
    {
        if(!m_contentMapper.allDifferencesSolved())
        {
            throw new UserException("Cannot save merge result until all conflicts have been solved.");
        }

        auto f = File(m_outputFileName, "w"); // open for writing
        for(int i = 0; i < getContentHeight(); i++)
        {
            auto line = getLineWithType(i);
            assert(line.type != LineType.UNRESOLVED_CONFLICT);
            assert(line.type != LineType.NONE);

            if(line.type != LineType.NO_SOURCE_LINE)
            {
                f.write(line.text);
            }
        }
        log(format("Merge result saved to file %s", m_outputFileName));
    }
}


