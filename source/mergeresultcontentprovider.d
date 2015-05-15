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
import std.string;
import std.typecons;

import common;
import icontentprovider;
import ilineprovider;
import myassert;

enum LineSource
{
    A,
    B,
    C,
    EDITED,
    NONE
}

unittest
{
    /* LineSource.A through C are used to index into arrays, so make sure they have the right values */
    assertEqual(LineSource.A, 0);
}

class MergeResultLine
{
    LineSource lineSource;

    /* set when lineSource is A/B/C */
    int lineNumber;

    /* set when lineSource is EDITED */
    string editedLine;
}

struct LineNumberRange
{
    int firstLine;
    int lastLine;
}

enum SectionType
{
    NO_CONFLICT,
    UNRESOLVED_CONFLICT,
    RESOLVED_CONFLICT
}

class MergeResultSection
{
private:
    static immutable int DEFAULT_LINE_SOURCE = LineSource.C;

    LineNumberRange[3] m_inputLineNumbers;

    SectionType m_sectionType;
    MergeResultLine[] m_mergeResultLines;

public:
    LineNumberRange getLineNumberRange(LineSource lineSource)
    {
        assert(lineSource <= LineSource.C);
        return m_inputLineNumbers[lineSource];
    }

    int outputSize()
    {
        if(m_sectionType == SectionType.NO_CONFLICT)
        {
            return m_inputLineNumbers[DEFAULT_LINE_SOURCE].lastLine - m_inputLineNumbers[DEFAULT_LINE_SOURCE].firstLine + 1;
        }
        else if(m_sectionType == SectionType.UNRESOLVED_CONFLICT)
        {
            return 1;
        }
        else
        {
            return to!int(m_mergeResultLines.length);
        }
    }

    Tuple!(LineSource, int) getLineInfo(int relativeLineNumber)
    {
        final switch(m_sectionType)
        {
        case SectionType.NO_CONFLICT:
            auto inputLineNumber = m_inputLineNumbers[DEFAULT_LINE_SOURCE].firstLine + relativeLineNumber;
            assert(inputLineNumber <= m_inputLineNumbers[DEFAULT_LINE_SOURCE].lastLine);

            return tuple(LineSource.C, inputLineNumber);

        case SectionType.UNRESOLVED_CONFLICT:
            return tuple(LineSource.NONE, -1);

        case SectionType.RESOLVED_CONFLICT:
            assert(relativeLineNumber < m_mergeResultLines.length);
            return tuple(LineSource.EDITED, relativeLineNumber);
        }
    }

    /* Retrieve a line from this section. The first line of the section is line 0. */
    string getEditedLine(int relativeLineNumber)
    {
        assert(m_sectionType != SectionType.NO_CONFLICT);
        assert(relativeLineNumber < m_mergeResultLines.length);
        assertEqual(m_mergeResultLines[relativeLineNumber].lineSource, LineSource.EDITED);

        return m_mergeResultLines[relativeLineNumber].editedLine;
    }
}

version(unittest)
{
    private Tuple!(SectionType, int, int, int, int, int, int) toTuple(MergeResultSection section)
    {
        return tuple(section.m_sectionType,
                     section.m_inputLineNumbers[LineSource.A].firstLine,
                     section.m_inputLineNumbers[LineSource.A].lastLine,
                     section.m_inputLineNumbers[LineSource.B].firstLine,
                     section.m_inputLineNumbers[LineSource.B].lastLine,
                     section.m_inputLineNumbers[LineSource.C].firstLine,
                     section.m_inputLineNumbers[LineSource.C].lastLine);
    }

    private Tuple!(SectionType, int, int, int, int, int, int)[] toTuples(DList!MergeResultSection sections)
    {
        Tuple!(SectionType, int, int, int, int, int, int)[] sectionTuples;
        foreach(section; sections)
        {
            sectionTuples ~= toTuple(section);
        }

        return sectionTuples;
    }
}


/**
 * ModifiedContentProvider is responsible for providing a view on the content
 * from an ILineProvider plus modifications. When a line of content is
 * requested, it checks its list of Modifications to see if it should return an
 * line from the ILineProvider or instead a line from one of the modifications.
 */
class MergeResultContentProvider: IContentProvider
{
private:
    shared ILineProvider[3] m_lps;
    DList!MergeResultSection m_mergeResultSections;

public:
    this(shared ILineProvider lps[3])
    {
        m_lps = lps;
    }

    private static DList!MergeResultSection calculateMergeResultSections(Diff3LineArray d3la)
    {
        DList!MergeResultSection mergeResultSections = make!(DList!MergeResultSection);

        int prev_equality = -1;
        int lastNonEmptyLineA;
        int lastNonEmptyLineB;
        int lastNonEmptyLineC;
        MergeResultSection section;
        foreach(d3l; d3la)
        {
            int equality = (d3l.bAEqB ? 1 : 0) | (d3l.bAEqC ? 2 : 0) | (d3l.bBEqC ? 4 : 0);

            if(equality != prev_equality)
            {
                if(prev_equality != -1)
                {
                    for(int i = LineSource.A; i <= LineSource.C; i++)
                    {
                        assertEqual(section.m_inputLineNumbers[i].firstLine == -1,
                                    section.m_inputLineNumbers[i].lastLine == -1,
                                    format("for line source %d firstLine was %d and lastLine was %d", 
                                            i, section.m_inputLineNumbers[i].firstLine, section.m_inputLineNumbers[i].lastLine));
                    }

                    mergeResultSections.insertBack(section);
                }
                section = new MergeResultSection();
                section.m_sectionType = (equality == 7) ? SectionType.NO_CONFLICT : SectionType.UNRESOLVED_CONFLICT;
                section.m_inputLineNumbers[LineSource.A].firstLine = d3l.lineA;
                section.m_inputLineNumbers[LineSource.B].firstLine = d3l.lineB;
                section.m_inputLineNumbers[LineSource.C].firstLine = d3l.lineC;
                section.m_inputLineNumbers[LineSource.A].lastLine = d3l.lineA;
                section.m_inputLineNumbers[LineSource.B].lastLine = d3l.lineB;
                section.m_inputLineNumbers[LineSource.C].lastLine = d3l.lineC;
            }
            else
            {
                if(d3l.lineA != -1) section.m_inputLineNumbers[LineSource.A].lastLine = d3l.lineA;
                if(d3l.lineB != -1) section.m_inputLineNumbers[LineSource.B].lastLine = d3l.lineB;
                if(d3l.lineC != -1) section.m_inputLineNumbers[LineSource.C].lastLine = d3l.lineC;
            }
            prev_equality = equality;
        }
        if(prev_equality != -1)
        {
            for(int i = LineSource.A; i <= LineSource.C; i++)
            {
                assertEqual(section.m_inputLineNumbers[i].firstLine == -1,
                            section.m_inputLineNumbers[i].lastLine == -1,
                            format("for line source %d firstLine was %d and lastLine was %d", 
                                    i, section.m_inputLineNumbers[i].firstLine, section.m_inputLineNumbers[i].lastLine));
            }
            mergeResultSections.insertBack(section);
        }
        return mergeResultSections;
    }

    unittest
    {
        /* Test a single one-line non-conflicted section */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 1,  11,  21, true, true, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.NO_CONFLICT, 1, 1, 11, 11, 21, 21));
        assertEqual(sectionTuples.length, 1);
    }

    unittest
    {
        /* Test a single multi-line non-conflicted section */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 0,  10,  20, true, true, true));
        d3la.insertBack(Diff3Line( 1,  11,  21, true, true, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.NO_CONFLICT, 0, 1, 10, 11, 20, 21));
        assertEqual(sectionTuples.length, 1);
    }

    unittest
    {
        /* Test a single multi-line conflicted section */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 0,  10,  20, false, true, true));
        d3la.insertBack(Diff3Line( 1,  11,  21, false, true, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.UNRESOLVED_CONFLICT, 0, 1, 10, 11, 20, 21));
        assertEqual(sectionTuples.length, 1);
    }

    unittest
    {
        /* Test differently conflicting sections */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 0,  10,  20, false, true, true));
        d3la.insertBack(Diff3Line( 1,  11,  21, false, true, true));
        d3la.insertBack(Diff3Line( 2,  12,  22, true, false, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.UNRESOLVED_CONFLICT, 0, 1, 10, 11, 20, 21));
        assertEqual(sectionTuples[1], tuple(SectionType.UNRESOLVED_CONFLICT, 2, 2, 12, 12, 22, 22));
        assertEqual(sectionTuples.length, 2);
    }

    unittest
    {
        /* Test a conflicting and a non-conflicting section */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 0,  10,  20, false, true, true));
        d3la.insertBack(Diff3Line( 1,  11,  21, false, true, true));
        d3la.insertBack(Diff3Line( 2,  12,  22, true, true, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.UNRESOLVED_CONFLICT, 0, 1, 10, 11, 20, 21));
        assertEqual(sectionTuples[1], tuple(SectionType.NO_CONFLICT, 2, 2, 12, 12, 22, 22));
        assertEqual(sectionTuples.length, 2);
    }

    unittest
    {
        /* Test conflicting sections with gaps */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 0,  10,  20, false, true, true));
        d3la.insertBack(Diff3Line(-1,  11,  21, false, true, true));
        d3la.insertBack(Diff3Line( 2,  12,  22, true, false, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.UNRESOLVED_CONFLICT, 0, 0, 10, 11, 20, 21));
        assertEqual(sectionTuples[1], tuple(SectionType.UNRESOLVED_CONFLICT, 2, 2, 12, 12, 22, 22));
        assertEqual(sectionTuples.length, 2);
    }

    unittest
    {
        /* Test conflicting sections without no lines at all in one of the files */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line(-1,  10,  20, false, true, true));
        d3la.insertBack(Diff3Line(-1,  11,  21, false, true, true));
        d3la.insertBack(Diff3Line( 2,  12,  22, true, false, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(SectionType.UNRESOLVED_CONFLICT, -1, -1, 10, 11, 20, 21));
        assertEqual(sectionTuples[1], tuple(SectionType.UNRESOLVED_CONFLICT, 2, 2, 12, 12, 22, 22));
        assertEqual(sectionTuples.length, 2);
    }


    void determineMergeResultSections(Diff3LineArray d3la)
    {
        assert(m_mergeResultSections.empty);
        m_mergeResultSections = calculateMergeResultSections(d3la);
    }

    /* IContentProvider methods */

    Nullable!string get(int line)
    {
        assert(!m_mergeResultSections.empty);

        foreach(section; m_mergeResultSections)
        {
            if(line < section.outputSize)
            {
                Nullable!string result;
                auto info = section.getLineInfo(line);

                switch(info[0])
                {
                case LineSource.EDITED:
                    result = section.getEditedLine(info[1]);
                    break;
                case LineSource.NONE:
                    result = "<unresolved conflict>";
                    break;
                default:
                    result = m_lps[info[0]].get(info[1]);
                    break;
                }
                return result;
            }
            else
            {
                line -= section.outputSize;
            }
        }
        assert(false);
    }

    int getContentWidth()
    {
        /* TODO: implement */
        return 1000;
    }

    int getContentHeight()
    {
        int numberOfLines = 0;
        foreach(section; m_mergeResultSections)
        {
            numberOfLines += section.outputSize;
        }
        return numberOfLines;
    }
}


