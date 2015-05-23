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
import icontentprovider;
import ilineprovider;
import myassert;

enum LineSource
{
    A,
    B,
    C,
    UNDEFINED
}

enum LineState
{
    ORIGINAL,
    EDITED,
    NONE
}

struct LineNumberRange
{
    int firstLine;
    int lastLine;
}

class MergeResultSection
{
private:
    static immutable int DEFAULT_LINE_SOURCE = LineSource.C;

    LineNumberRange[3] m_inputLineNumbers;
    LineNumberRange m_diff3LineNumbers;

    bool m_isConflict;
    LineSource[] m_selectedSources;

public:
    LineNumberRange getLineNumberRange(LineSource lineSource)
    {
        assert(lineSource != LineSource.UNDEFINED);
        return m_inputLineNumbers[lineSource];
    }

    int outputSize()
    {
        if(m_isConflict)
        {
            // TODO: apply modifications
            auto count = 0;

            if(m_selectedSources.length == 0)
            {
                /* <unresolved conflict> */
                count = 1;
            }
            else
            {
                foreach(selectedSource; m_selectedSources)
                {
                    if(m_inputLineNumbers[selectedSource].firstLine == -1)
                    {
                        count += 1;
                    }
                    else
                    {
                        count += m_inputLineNumbers[selectedSource].lastLine - m_inputLineNumbers[selectedSource].firstLine + 1;
                    }
                }
            }
            return count;
        }
        else
        {
            return m_inputLineNumbers[DEFAULT_LINE_SOURCE].lastLine - m_inputLineNumbers[DEFAULT_LINE_SOURCE].firstLine + 1;
        }
    }

    void toggle(LineSource lineSource)
    {
        assert(m_isConflict);
        if(m_selectedSources.canFind(lineSource))
        {
            m_selectedSources = m_selectedSources.where( (LineSource ls) { return ls != lineSource; } );
        }
        else
        {
            m_selectedSources ~= lineSource;
        }
    }

    Tuple!(LineState, LineSource, int) getLineInfo(int relativeLineNumber)
    {
        // TODO: apply modifications
        if(m_isConflict)
        {
            log(format("getLineInfo for line %d", relativeLineNumber));
            if(m_selectedSources.length == 0)
            {
                return tuple(LineState.NONE, LineSource.UNDEFINED, -1);
            }
            foreach(selectedSource; m_selectedSources)
            {
                int linesFromSelectedSource;
                bool selectedSourceHasNoLines = (m_inputLineNumbers[selectedSource].firstLine == -1);
                if(selectedSourceHasNoLines)
                {
                    linesFromSelectedSource = 1;
                }
                else
                {
                    linesFromSelectedSource = m_inputLineNumbers[selectedSource].lastLine - m_inputLineNumbers[selectedSource].firstLine + 1;
                }
                if(relativeLineNumber < linesFromSelectedSource)
                {
                    if(selectedSourceHasNoLines)
                    {
                        return tuple(LineState.ORIGINAL, selectedSource, -1);
                    }
                    else
                    {
                        return tuple(LineState.ORIGINAL, selectedSource, m_inputLineNumbers[selectedSource].firstLine + relativeLineNumber);
                    }
                }
            }
            assert(false);
        }
        else
        {
            auto inputLineNumber = m_inputLineNumbers[DEFAULT_LINE_SOURCE].firstLine + relativeLineNumber;
            assert(inputLineNumber <= m_inputLineNumbers[DEFAULT_LINE_SOURCE].lastLine);

            return tuple(LineState.ORIGINAL, LineSource.C, inputLineNumber);
        }
    }

    /* Retrieve a line from this section. The first line of the section is line 0. */
    string getEditedLine(int relativeLineNumber)
    {
        assert(m_isConflict);

        /* TODO: implement */

        return "";
    }
}

version(unittest)
{
    private Tuple!(bool, int, int, int, int, int, int, int, int) toTuple(MergeResultSection section)
    {
        return tuple(section.m_isConflict,
                     section.m_inputLineNumbers[LineSource.A].firstLine,
                     section.m_inputLineNumbers[LineSource.A].lastLine,
                     section.m_inputLineNumbers[LineSource.B].firstLine,
                     section.m_inputLineNumbers[LineSource.B].lastLine,
                     section.m_inputLineNumbers[LineSource.C].firstLine,
                     section.m_inputLineNumbers[LineSource.C].lastLine,
                     section.m_diff3LineNumbers.firstLine,
                     section.m_diff3LineNumbers.lastLine);
    }

    private Tuple!(bool, int, int, int, int, int, int, int, int)[] toTuples(DList!MergeResultSection sections)
    {
        Tuple!(bool, int, int, int, int, int, int, int, int)[] sectionTuples;
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
    this(shared ILineProvider lps0,
         shared ILineProvider lps1,
         shared ILineProvider lps2)
    {
        m_lps[0] = lps0;
        m_lps[1] = lps1;
        m_lps[2] = lps2;
    }

    private static DList!MergeResultSection calculateMergeResultSections(Diff3LineArray d3la)
    {
        DList!MergeResultSection mergeResultSections = make!(DList!MergeResultSection);

        int prev_equality = -1;
        int lastNonEmptyLineA;
        int lastNonEmptyLineB;
        int lastNonEmptyLineC;
        MergeResultSection section;
        int d3l_index = 0;
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
                section.m_isConflict = (equality != 7);
                section.m_inputLineNumbers[LineSource.A].firstLine = d3l.lineA;
                section.m_inputLineNumbers[LineSource.B].firstLine = d3l.lineB;
                section.m_inputLineNumbers[LineSource.C].firstLine = d3l.lineC;
                section.m_inputLineNumbers[LineSource.A].lastLine = d3l.lineA;
                section.m_inputLineNumbers[LineSource.B].lastLine = d3l.lineB;
                section.m_inputLineNumbers[LineSource.C].lastLine = d3l.lineC;
                section.m_diff3LineNumbers.firstLine = d3l_index;
                section.m_diff3LineNumbers.lastLine = d3l_index;
            }
            else
            {
                if(d3l.lineA != -1) section.m_inputLineNumbers[LineSource.A].lastLine = d3l.lineA;
                if(d3l.lineB != -1) section.m_inputLineNumbers[LineSource.B].lastLine = d3l.lineB;
                if(d3l.lineC != -1) section.m_inputLineNumbers[LineSource.C].lastLine = d3l.lineC;
                section.m_diff3LineNumbers.lastLine = d3l_index;
            }
            prev_equality = equality;
            d3l_index++;
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
        assertEqual(sectionTuples[0], tuple(false, 1, 1, 11, 11, 21, 21, 0, 0));
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
        assertEqual(sectionTuples[0], tuple(false, 0, 1, 10, 11, 20, 21, 0, 1));
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
        assertEqual(sectionTuples[0], tuple(true, 0, 1, 10, 11, 20, 21, 0, 1));
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
        assertEqual(sectionTuples[0], tuple(true, 0, 1, 10, 11, 20, 21, 0, 1));
        assertEqual(sectionTuples[1], tuple(true, 2, 2, 12, 12, 22, 22, 2, 2));
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
        assertEqual(sectionTuples[0], tuple(true, 0, 1, 10, 11, 20, 21, 0, 1));
        assertEqual(sectionTuples[1], tuple(false, 2, 2, 12, 12, 22, 22, 2, 2));
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
        assertEqual(sectionTuples[0], tuple(true, 0, 0, 10, 11, 20, 21, 0, 1));
        assertEqual(sectionTuples[1], tuple(true, 2, 2, 12, 12, 22, 22, 2, 2));
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
        assertEqual(sectionTuples[0], tuple(true, -1, -1, 10, 11, 20, 21, 0, 1));
        assertEqual(sectionTuples[1], tuple(true, 2, 2, 12, 12, 22, 22, 2, 2));
        assertEqual(sectionTuples.length, 2);
    }


    void determineMergeResultSections(Diff3LineArray d3la)
    {
        assert(m_mergeResultSections.empty);
        m_mergeResultSections = calculateMergeResultSections(d3la);
    }

    void automaticallyResolveConflicts(Diff3LineArray d3la)
    {
        assert(!m_mergeResultSections.empty);

        foreach(section; m_mergeResultSections)
        {
            auto d3l = d3la[section.m_diff3LineNumbers.firstLine];

            if(!section.m_isConflict)
                continue;

            if(d3l.bAEqC)
            {
                if(d3l.bAEqB)
                {
                    /* Everything is the same, but we shouldn't have come here for non-conflict sections */
                    assert(false);
                }
                else
                {
                    section.toggle(LineSource.B);
                }
            }
            else
            {
                if(d3l.bAEqB)
                {
                    section.toggle(LineSource.C);
                }
                else
                {
                    if(d3l.bBEqC)
                    {
                        /* Choose either B or C */
                        section.toggle(LineSource.C);
                    }
                    else
                    {
                        /* Unresolvable conflict, don't choose anything */
                    }
                }
            }
        }
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

                final switch(info[0])
                {
                case LineState.EDITED:
                    result = section.getEditedLine(info[2]);
                    break;
                case LineState.NONE:
                    result = "<unresolved conflict>\n";
                    break;
                case LineState.ORIGINAL:
                    if(info[2] == -1)
                    {
                        result = "<no source line>\n";
                    }
                    else
                    {
                        result = m_lps[info[1]].get(info[2]);
                    }
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


