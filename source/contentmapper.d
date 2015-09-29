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
module contentmapper;

import std.algorithm;
import std.container;
import std.range;
import std.signals;
import std.string;
import std.typecons;

import common;
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

/**
 * Information about the location of a section within the content for each
 * pane, as well as the difference status of the section.
 */
struct SectionInfo
{
    /** The content line numbers in the input panes associated with the section */
    LineNumberRange inputPaneLineNumbers;

    /** The content line numbers in the merge result pane associated with the section */
    LineNumberRange mergeResultPaneLineNumbers;

    /** Whether or not the section represents a difference between input files */
    bool isDifference;
}

/**
 * Information about a line that indicates where the text of that line is stored.
  */
struct LineInfo
{
    /** Whether this line is from one of the input files (ORIGINAL) or has been modified by the user (EDITED) */
    LineState state;
    union
    {
        /** The input file this line is from (A/B/C) (only if state is ORIGINAL) */
        LineSource source;
        /** The section index of the ModifiableMergeResultSection that contains the edited line (only if state is EDITED) */
        int sectionIndex;
    }
    /** The line number in the input file if state is ORIGINAL or the line number relative to the start of the section if state is EDITED. */
    int lineNumber;
}

/**
 * The MergeResultSection maintains the user's conflict resolution choices for
 * a single difference section and provides source file and line number
 * information for the lines in this section.
 */
class MergeResultSection
{
private:
    static immutable int DEFAULT_LINE_SOURCE = LineSource.C;

    LineNumberRange[3] m_inputLineNumbers;
    LineNumberRange m_diff3LineNumbers;

    bool m_isDifference;
    LineSource[] m_selectedSources;

public:
    this(bool isDifference,
         int firstInputLineA, int lastInputLineA,
         int firstInputLineB, int lastInputLineB,
         int firstInputLineC, int lastInputLineC,
         int firstDiff3Line, int lastDiff3Line)
    {
        m_isDifference = isDifference;
        m_inputLineNumbers[LineSource.A].firstLine = firstInputLineA;
        m_inputLineNumbers[LineSource.B].firstLine = firstInputLineB;
        m_inputLineNumbers[LineSource.C].firstLine = firstInputLineC;
        m_inputLineNumbers[LineSource.A].lastLine = lastInputLineA;
        m_inputLineNumbers[LineSource.B].lastLine = lastInputLineB;
        m_inputLineNumbers[LineSource.C].lastLine = lastInputLineC;
        m_diff3LineNumbers.firstLine = firstDiff3Line;
        m_diff3LineNumbers.lastLine = lastDiff3Line;
    }

    LineNumberRange getLineNumberRange(LineSource lineSource)
    {
        assert(lineSource != LineSource.UNDEFINED);
        return m_inputLineNumbers[lineSource];
    }

    int getOutputSize()
    {
        int count = 0;

        if(m_isDifference)
        {
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
        }
        else
        {
            count = m_inputLineNumbers[DEFAULT_LINE_SOURCE].lastLine - m_inputLineNumbers[DEFAULT_LINE_SOURCE].firstLine + 1;
        }

        return count;
    }

    void toggle(LineSource lineSource)
    {
        assert(m_isDifference);

        if(m_selectedSources.canFind(lineSource))
        {
            m_selectedSources = m_selectedSources.where( (LineSource ls) { return ls != lineSource; } );
        }
        else
        {
            m_selectedSources ~= lineSource;
        }
    }

    LineInfo getLineInfo(int relativeLineNumber)
    {
        LineInfo lineInfo;

        if(m_isDifference)
        {
            if(m_selectedSources.length == 0)
            {
                assert(relativeLineNumber == 0);

                lineInfo.state = LineState.NONE;
                lineInfo.source = LineSource.UNDEFINED;
                lineInfo.lineNumber = -1;
                return lineInfo;
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
                        lineInfo.state = LineState.ORIGINAL;
                        lineInfo.source = selectedSource;
                        lineInfo.lineNumber = -1;
                        return lineInfo;
                    }
                    else
                    {
                        lineInfo.state = LineState.ORIGINAL;
                        lineInfo.source = selectedSource;
                        lineInfo.lineNumber = m_inputLineNumbers[selectedSource].firstLine + relativeLineNumber;
                        return lineInfo;
                    }
                }

                relativeLineNumber -= linesFromSelectedSource;
            }
            assert(false);
        }
        else
        {
            auto inputLineNumber = m_inputLineNumbers[DEFAULT_LINE_SOURCE].firstLine + relativeLineNumber;
            assert(inputLineNumber <= m_inputLineNumbers[DEFAULT_LINE_SOURCE].lastLine);

            lineInfo.state = LineState.ORIGINAL;
            lineInfo.source = LineSource.C;
            lineInfo.lineNumber = inputLineNumber;
            return lineInfo;
        }
    }

    bool isSolved()
    {
        return !m_isDifference || m_selectedSources.length != 0;
    }
}

enum RelativePosition
{
    BEFORE,
    OVERLAPPING,
    AFTER
}

pure int calculateOverlap(int firstLine1, int numberOfLines1, int firstLine2, int numberOfLines2)
{
    int beyondLastLine1 = firstLine1 + numberOfLines1;
    int beyondLastLine2 = firstLine2 + numberOfLines2;

    int overlap = min(beyondLastLine1, beyondLastLine2) - max(firstLine1, firstLine2);

    return overlap;
}

unittest
{
    assertEqual(calculateOverlap(2, 2, 3, 2), 1);
    assertEqual(calculateOverlap(3, 2, 2, 2), 1);
    assertEqual(calculateOverlap(2, 3, 2, 2), 2);
}

/**
 * This class represents a line-based modification of text.
 * 
 * It replaces a number of lines in the section it is applied to with lines
 * that are contained in the modification.
 */
struct Modification
{
    /**
     * The first line of the modification relative to the start of the content
     * of the ModifiableMergeResultSection it is applied to.
     *
     * In a modification passed to
     * ModifiableMergeResultSection.applyModification this is the line number
     * in the current (possibly already edited) content of the section.
     *
     * Once stored in a section, firstLine will have been modified to be
     * relative to the original content of the section without modifications.
     *
     * Always keeping firstLine relative to the original content makes it
     * possible to insert additional modifications before existing ones without
     * having to adapt firstLine in the existing modifications.
     */
    int firstLine;
    /**
     * The number of lines in the section that will be replaced by new lines in
     * this modification */
    int originalLineCount;
    /**
     * The number of lines that will replace the original lines
     */
    int editedLineCount;
    /**
     * The replacement text for the lines that this modification changes
     */
    string[] lines;

    this(int firstLine, int originalLineCount, int editedLineCount, string[] lines)
    {
        this.firstLine = firstLine;
        this.originalLineCount = originalLineCount;
        this.editedLineCount = editedLineCount;
        this.lines = lines;
    }

    unittest
    {
        auto mod = Modification(1, 2, 3, ["one", "two"]);

        assertEqual(mod.firstLine, 1);
        assertEqual(mod.originalLineCount, 2);
        assertEqual(mod.editedLineCount, 3);
        assertEqual(mod.lines[0], "one");
        assertEqual(mod.lines[1], "two");
    }

    /**
     * Return whether this modification is BEFORE, AFTER or OVERLAPPING the specified modification.
     */
    RelativePosition checkRelativePosition(Modification newModification)
    {
        if(firstLine + editedLineCount < newModification.firstLine)
        {
            return RelativePosition.BEFORE;
        }
        else if(newModification.firstLine + newModification.originalLineCount < firstLine)
        {
            return RelativePosition.AFTER;
        }
        else
        {
            return RelativePosition.OVERLAPPING;
        }
    }

    /**
     * Merge another modification with this modification and return the merged modification.
     *
     * This function is meant to be called when applying a modification that
     * overlaps with an existing modification to make sure that in the end all
     * modifications to a section are non-overlapping.
     */
    Modification merge(Modification newModification)
    {
        Modification mergedModification;

        auto overlapWithExistingEditedLines = calculateOverlap(newModification.firstLine, newModification.originalLineCount,
                                                               firstLine, editedLineCount);

        mergedModification.firstLine = min(firstLine, newModification.firstLine);
        mergedModification.originalLineCount = originalLineCount +
                                              newModification.originalLineCount -
                                              overlapWithExistingEditedLines;
        mergedModification.editedLineCount = editedLineCount +
                                            newModification.editedLineCount -
                                            overlapWithExistingEditedLines;

        int linesBefore = 0;
        int linesAfter = 0;

        int remainingEditedLines = editedLineCount - overlapWithExistingEditedLines;

        if(remainingEditedLines > 0)
        {
            if(firstLine < newModification.firstLine)
            {
                linesBefore = remainingEditedLines;
            }
            else if(firstLine + editedLineCount >
                    newModification.firstLine + newModification.originalLineCount)
            {
                linesAfter = remainingEditedLines;
            }
            else
            {
                assert(false);
            }
        }

        mergedModification.lines.length = linesBefore + newModification.lines.length + linesAfter;
        mergedModification.lines[0..linesBefore] = lines[0..linesBefore];
        mergedModification.lines[linesBefore..(linesBefore + newModification.lines.length)] = newModification.lines;
        mergedModification.lines[linesBefore + newModification.lines.length..$] = lines[$ - linesAfter..$];

        return mergedModification;
    }

    unittest
    {
        /* Check merge of modification that overlaps with end of existing modification */

        // 1  1       1
        // 2  a1      a1
        // 3  a2  b1  b1
        // 4  3   b2  b2
        // 5  4   b3  b3
        // 6  5       4
        auto mod = Modification(2, 1, 2, ["a1", "a2"]).merge(Modification(3, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(mod, Modification(2, 2, 4, ["a1", "b1", "b2", "b3"]));
    }

    unittest
    {
        /* Check merge of modification that overlaps with all of existing modification */

        // 1  1       1
        // 2  a1  b1  b1
        // 3  a2  b2  b2
        // 4  3   b3  b3
        // 5  4       3
        auto mod = Modification(2, 1, 2, ["a1", "a2"]).merge(Modification(2, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(mod, Modification(2, 1, 3, ["b1", "b2", "b3"]));
    }

    unittest
    {
        /* Check merge of modification that overlaps with beginning of existing modification */

        // 1  1       1
        // 2  a1  b1  b1
        // 3  a2  b2  b2
        // 4  a3      a2
        // 5  3       a3
        // 6  4       3
        auto mod = Modification(2, 1, 3, ["a1", "a2", "a3"]).merge(Modification(2, 1, 2, ["b1", "b2"]));
        assertEqual(mod, Modification(2, 1, 4, ["b1", "b2", "a2", "a3"]));
    }

    unittest
    {
        /* Check merge of modification that starts before and overlaps with beginning of existing modification */

        // 1  1       1
        // 2  2   b1  b1
        // 3  a1  b2  b2
        // 4  a2  b3  b3
        // 5  4       a2
        // 6  5       4
        auto mod = Modification(3, 1, 2, ["a1", "a2"]).merge(Modification(2, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(mod, Modification(2, 2, 4, ["b1", "b2", "b3", "a2"]));
    }
}

/**
 * The ModifiableMergeResultSection is a MergeResultSection that adds the
 * ability to apply modifications to its content.
 */
class ModifiableMergeResultSection: MergeResultSection
{
private:
    DList!Modification m_modifications;

public:
    this(bool isDifference,
         int firstInputLineA, int lastInputLineA,
         int firstInputLineB, int lastInputLineB,
         int firstInputLineC, int lastInputLineC,
         int firstDiff3Line, int lastDiff3Line)
    {
        super(isDifference,
              firstInputLineA, lastInputLineA,
              firstInputLineB, lastInputLineB,
              firstInputLineC, lastInputLineC,
              firstDiff3Line, lastDiff3Line);
    }

    override int getOutputSize()
    {
        auto numberOfLines = super.getOutputSize();
        foreach(modification; m_modifications)
        {
            numberOfLines -= modification.originalLineCount;
            numberOfLines += modification.editedLineCount;
        }

        /* If the edit has removed all lines and this section represents a
         * difference between input files, then this section will consist of a
         * single "no source line" line.
         * If the input files are the same for this section, then the section
         * size will become 0, which is the same as having been removed
         * entirely. */
        if(numberOfLines == 0 && m_isDifference)
        {
            numberOfLines = 1;
        }
        return numberOfLines;
    }

    override void toggle(LineSource lineSource)
    {
        // throw away all modifications
        super.toggle(lineSource);
    }

    /**
     * Return where the content of a line can be found.
     *
     * Edited lines can be retrieved with a call to getEditedLine, passing the
     * lineNumber from the LineInfo returned by this function.
     *
     * Params:
     *   relativeLineNumber = the line number relative to the current
     *                        (possibly edited) content of the section
     */
    override LineInfo getLineInfo(int relativeLineNumber)
    {
        auto originalRelativeLineNumber = relativeLineNumber;

        foreach(modification; m_modifications)
        {
            if(relativeLineNumber >= modification.firstLine)
            {
                if(relativeLineNumber < modification.firstLine + modification.editedLineCount)
                {
                    LineInfo lineInfo;
                    lineInfo.state = LineState.EDITED;
                    lineInfo.lineNumber = originalRelativeLineNumber;
                    return lineInfo;
                }
                else
                {
                    relativeLineNumber -= modification.editedLineCount;
                    relativeLineNumber += modification.originalLineCount;
                }
            }
            else
            {
                return super.getLineInfo(relativeLineNumber);
            }
        }

        auto numberOfLines = super.getOutputSize();
        if(relativeLineNumber >= numberOfLines)
        {
            /* This should only happen in case the section is completely empty
             * and the "no source line" line is being retrieved */
            assert(originalRelativeLineNumber == 0);

            LineInfo lineInfo;
            lineInfo.state = LineState.EDITED;
            lineInfo.lineNumber = -1;
            return lineInfo;
        }
        else
        {
            return super.getLineInfo(relativeLineNumber);
        }
    }

    override bool isSolved()
    {
        // if edited then solved, otherwise...
        return super.isSolved();
    }

    /**
     * This function applies a modification to a section.
     *
     * Because the firstLine member of existing modifications 
     * always refers to the line number in the original unmodified
     * content of the section (see Modification.firstLine), there is no need to modify existing
     * modifications upon insertion of another one before them.
     *
     * However, the firstLine member of the modification being added is
     * relative to the start of the current (possibly modified) content of the
     * section. It will therefore have to be modified once before it is stored.
     */
    void applyModification(Modification newmod)
    {
        DList!Modification updatedModifications;

        assert(newmod.firstLine + newmod.originalLineCount <= getOutputSize());

        bool newmodInserted = false;
        auto modRange = m_modifications[];
        while(!modRange.empty)
        {
            switch(modRange.front.checkRelativePosition(newmod))
            {
            case RelativePosition.BEFORE:
                updatedModifications.insertBack(modRange.front);
                newmod.firstLine -= modRange.front.editedLineCount;
                newmod.firstLine += modRange.front.originalLineCount;
                break;
            case RelativePosition.OVERLAPPING:
                newmod = modRange.front.merge(newmod);
                break;
            case RelativePosition.AFTER:
                if(!newmodInserted)
                {
                    updatedModifications.insertBack(newmod);
                    newmodInserted = true;
                }
                updatedModifications.insertBack(modRange.front);
                break;
            default:
                assert(false);
            }
            modRange.popFront();
        }

        if(!newmodInserted)
        {
            updatedModifications.insertBack(newmod);
            newmodInserted = true;
        }

        m_modifications = updatedModifications;
    }

    /** Retrieve an edited line from this section. The first line of the section is line 0. */
    string getEditedLine(int relativeLineNumber)
    {
        foreach(modification; m_modifications)
        {
            if(relativeLineNumber >= modification.firstLine)
            {
                if(relativeLineNumber < modification.firstLine + modification.editedLineCount)
                {
                    return modification.lines[relativeLineNumber - modification.firstLine];
                }
                else
                {
                    relativeLineNumber -= modification.editedLineCount;
                    relativeLineNumber += modification.originalLineCount;
                }
            }
            else
            {
                break;
            }
        }
        /* this function should never be called for a line that is not an edited one */
        assert(false);
    }
}

version(unittest)
{
    private Tuple!(LineState, int)[] toLineInfos(MergeResultSection section)
    {
        return iota(0, section.getOutputSize())
                    .map!(i => section.getLineInfo(i))
                    .map!(li => tuple(li.state, li.lineNumber)).array;
    }
}

unittest
{
    /* Check that a clean section contains all original lines */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 12,
                                                                            10, 12,
                                                                            10, 12,
                                                                            20, 22);
    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.ORIGINAL, 11),
                                               tuple(LineState.ORIGINAL, 12) ]);
}

unittest
{
    /* Check the effect of a modification applied to the center line */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 12,
                                                                            10, 12,
                                                                            10, 12,
                                                                            20, 22);
    section.applyModification(Modification(1, 1, 1, [ "edit1" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.ORIGINAL, 12) ]);
    assertEqual(section.getEditedLine(1), "edit1");
}

unittest
{
    /* Check if a modification can increase the number of lines in a section */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 12,
                                                                            10, 12,
                                                                            10, 12,
                                                                            20, 22);
    section.applyModification(Modification(1, 1, 2, [ "edit1", "edit2" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.EDITED,    2),
                                               tuple(LineState.ORIGINAL, 12) ]);
    assertEqual(section.getEditedLine(1), "edit1");
    assertEqual(section.getEditedLine(2), "edit2");
}

unittest
{
    /* Check if a modification can decrease the number of lines in a section */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(1, 2, 1, [ "edit1" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.ORIGINAL, 13) ]);
    assertEqual(section.getEditedLine(1), "edit1");
}

unittest
{
    /* Check if a modification can remove lines without replacing them with edited lines */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(1, 2, 0, []));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.ORIGINAL, 13) ]);
}

unittest
{
    /* Check if a modification can be applied before an existing modification */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(3, 1, 1, [ "edit1" ]));
    section.applyModification(Modification(1, 1, 1, [ "edit2" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.ORIGINAL, 12),
                                               tuple(LineState.EDITED,    3) ]);
    assertEqual(section.getEditedLine(1), "edit2");
    assertEqual(section.getEditedLine(3), "edit1");
}

unittest
{
    /* Check if a modification can be applied after an existing modification */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(1, 1, 1, [ "edit1" ]));
    section.applyModification(Modification(3, 1, 1, [ "edit2" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.ORIGINAL, 12),
                                               tuple(LineState.EDITED,    3) ]);
    assertEqual(section.getEditedLine(1), "edit1");
    assertEqual(section.getEditedLine(3), "edit2");
}

unittest
{
    /* Check if a modification can be applied before an existing modification and changing the offset of the existing modification */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 14,
                                                                            10, 14,
                                                                            10, 14,
                                                                            20, 24);
    section.applyModification(Modification(3, 1, 1, [ "edit1" ]));
    section.applyModification(Modification(1, 1, 2, [ "edit2a", "edit2b" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.EDITED,    2),
                                               tuple(LineState.ORIGINAL, 12),
                                               tuple(LineState.EDITED,    4),
                                               tuple(LineState.ORIGINAL, 14) ]);
    assertEqual(section.getEditedLine(1), "edit2a");
    assertEqual(section.getEditedLine(2), "edit2b");
    assertEqual(section.getEditedLine(4), "edit1");
}

unittest
{
    /* Check if a modification can be applied that overlaps the end of an existing modification */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(1, 2, 2, [ "edit1a", "edit1b" ]));
    section.applyModification(Modification(2, 2, 2, [ "edit2a", "edit2b" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.EDITED,    2),
                                               tuple(LineState.EDITED,    3) ]);
    assertEqual(section.getEditedLine(1), "edit1a");
    assertEqual(section.getEditedLine(2), "edit2a");
    assertEqual(section.getEditedLine(3), "edit2b");
}

unittest
{
    /* Check if a modification can be applied that overlaps the beginning of an existing modification */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(2, 2, 2, [ "edit1a", "edit1b" ]));
    section.applyModification(Modification(1, 2, 2, [ "edit2a", "edit2b" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.EDITED,    2),
                                               tuple(LineState.EDITED,    3) ]);
    assertEqual(section.getEditedLine(1), "edit2a");
    assertEqual(section.getEditedLine(2), "edit2b");
    assertEqual(section.getEditedLine(3), "edit1b");
}

unittest
{
    /* Check if a modification can be applied that overlaps the beginning of an existing modification and changes the offset of the existing modification */
    ModifiableMergeResultSection section = new ModifiableMergeResultSection(false,
                                                                            10, 13,
                                                                            10, 13,
                                                                            10, 13,
                                                                            20, 23);
    section.applyModification(Modification(2, 2, 2, [ "edit1a", "edit1b" ]));
    section.applyModification(Modification(1, 2, 3, [ "edit2a", "edit2b", "edit2c" ]));

    assertArraysEqual(section.toLineInfos(), [ tuple(LineState.ORIGINAL, 10),
                                               tuple(LineState.EDITED,    1),
                                               tuple(LineState.EDITED,    2),
                                               tuple(LineState.EDITED,    3),
                                               tuple(LineState.EDITED,    4) ]);
    assertEqual(section.getEditedLine(1), "edit2a");
    assertEqual(section.getEditedLine(2), "edit2b");
    assertEqual(section.getEditedLine(3), "edit2c");
    assertEqual(section.getEditedLine(4), "edit1b");
}

alias Array!ModifiableMergeResultSection MergeResultSections;

version(unittest)
{
    private Tuple!(bool, int, int, int, int, int, int, int, int) toTuple(MergeResultSection section)
    {
        return tuple(section.m_isDifference,
                     section.m_inputLineNumbers[LineSource.A].firstLine,
                     section.m_inputLineNumbers[LineSource.A].lastLine,
                     section.m_inputLineNumbers[LineSource.B].firstLine,
                     section.m_inputLineNumbers[LineSource.B].lastLine,
                     section.m_inputLineNumbers[LineSource.C].firstLine,
                     section.m_inputLineNumbers[LineSource.C].lastLine,
                     section.m_diff3LineNumbers.firstLine,
                     section.m_diff3LineNumbers.lastLine);
    }

    private Tuple!(bool, int, int, int, int, int, int, int, int)[] toTuples(MergeResultSections sections)
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
 * The ContentMapper is responsible for keeping track of the source for each
 * line in the merge result. One possible source is the list of edited lines
 * that it also maintains. It must also be able to provide location and state
 * information for all difference sections in the merge result.
 */
class ContentMapper
{
private:
    MergeResultSections m_mergeResultSections;

    mixin Signal!(LineNumberRange) m_linesChanged;

public:
    this()
    {
    }

    private static MergeResultSections calculateMergeResultSections(Diff3LineArray d3la)
    {
        DList!ModifiableMergeResultSection mergeResultSections = make!(DList!ModifiableMergeResultSection);

        int prev_equality = -1;
        int lastNonEmptyLineA;
        int lastNonEmptyLineB;
        int lastNonEmptyLineC;
        ModifiableMergeResultSection section;
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
                section = new ModifiableMergeResultSection(equality != 7,
                                                           d3l.lineA, d3l.lineA,
                                                           d3l.lineB, d3l.lineB,
                                                           d3l.lineC, d3l.lineC,
                                                           d3l_index, d3l_index);
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
        return MergeResultSections(mergeResultSections[]);
    }

    unittest
    {
        /* Test a single one-line non-difference section */
        Diff3LineArray d3la = make!(Diff3LineArray);
        d3la.insertBack(Diff3Line( 1,  11,  21, true, true, true));
        auto sections = calculateMergeResultSections(d3la);
        auto sectionTuples = toTuples(sections);
        assertEqual(sectionTuples[0], tuple(false, 1, 1, 11, 11, 21, 21, 0, 0));
        assertEqual(sectionTuples.length, 1);
    }

    unittest
    {
        /* Test a single multi-line non-difference section */
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
        /* Test a single multi-line difference section */
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
        /* Test differently differing sections */
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
        /* Test a difference and a non-difference section */
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
        /* Test difference sections with gaps */
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
        /* Test difference sections without no lines at all in one of the files */
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

    void automaticallyResolveDifferences(Diff3LineArray d3la)
    {
        assert(!m_mergeResultSections.empty);

        foreach(section; m_mergeResultSections)
        {
            auto d3l = d3la[section.m_diff3LineNumbers.firstLine];

            if(!section.m_isDifference)
                continue;

            if(d3l.bAEqC)
            {
                if(d3l.bAEqB)
                {
                    /* Everything is the same, but we shouldn't have come here for non-difference sections */
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

    LineInfo getMergeResultLineInfo(int lineInMergeResultPane)
    {
        int sectionIndex = 0;
        foreach(section; m_mergeResultSections)
        {
            int sectionSize = section.getOutputSize();
            if(lineInMergeResultPane < sectionSize)
            {
                auto lineInfo = section.getLineInfo(lineInMergeResultPane);
                if(lineInfo.state == LineState.EDITED)
                {
                    lineInfo.sectionIndex = sectionIndex;
                }
                return lineInfo;
            }
            lineInMergeResultPane -= sectionSize;
            sectionIndex++;
        }
        assert(false);
    }

    void applyModification(Modification mod)
    {
        LineNumberRange modifiedRange;
        modifiedRange.firstLine = mod.firstLine;
        modifiedRange.lastLine = -1;

        foreach(section; m_mergeResultSections)
        {
            int sectionSize = section.getOutputSize();
            if(mod.firstLine < sectionSize)
            {
                auto linesInFollowingSections = (mod.firstLine + mod.originalLineCount) - sectionSize;

                if(linesInFollowingSections > 0)
                {
                    mod.originalLineCount -= linesInFollowingSections;
                }

                section.applyModification(mod);

                if(linesInFollowingSections <= 0)
                {
                    break;
                }

                mod = Modification(0, linesInFollowingSections, 0, []);
            }
            else
            {
                mod.firstLine -= sectionSize;
            }
        }

        m_linesChanged.emit(modifiedRange);
    }

    version(unittest)
    {
        private string[] toLines()
        {
            return iota(0, getContentHeight())
                        .map!(i => getMergeResultLineInfo(i))
                        .map!( (LineInfo li)
                                {
                                    if(li.state == LineState.ORIGINAL)
                                    {
                                        return format("original %d", li.lineNumber);
                                    }
                                    else if(li.state == LineState.EDITED)
                                    {
                                        if(li.lineNumber == -1)
                                        {
                                            return "no source line";
                                        }
                                        else
                                        {
                                            return getEditedLine(li.sectionIndex, li.lineNumber);
                                        }
                                    }
                                    else
                                    {
                                        assert(false);
                                    }
                                } ).array;
        }
    }

    unittest
    {
        /* Simple test to show that this kind of test works */
        auto cm = new ContentMapper();
        cm.m_mergeResultSections = MergeResultSections([ new ModifiableMergeResultSection(false,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          20, 21) ]);
        assertArraysEqual(cm.toLines(), [ "original 10",
                                          "original 11" ]);
    }

    unittest
    {
        /* Test a single modification within a section */
        auto cm = new ContentMapper();
        cm.m_mergeResultSections = MergeResultSections([ new ModifiableMergeResultSection(false,
                                                                                          10, 13,
                                                                                          10, 13,
                                                                                          10, 13,
                                                                                          20, 23) ]);
        cm.applyModification(Modification(1, 2, 1, [ "edited 1" ]));
        assertArraysEqual(cm.toLines(), [ "original 10",
                                          "edited 1",
                                          "original 13" ]);
    }

    unittest
    {
        /* Test that deleting a complete non-difference section leaves no lines */
        auto cm = new ContentMapper();
        cm.m_mergeResultSections = MergeResultSections([ new ModifiableMergeResultSection(false,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          20, 21) ]);
        cm.applyModification(Modification(0, 2, 0, []));
        assertArraysEqual(cm.toLines(), []);
    }

    unittest
    {
        /* Test that deleting a complete difference section leaves a single "no source line" line */
        auto cm = new ContentMapper();
        cm.m_mergeResultSections = MergeResultSections([ new ModifiableMergeResultSection(true,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          20, 21) ]);
        cm.applyModification(Modification(0, 2, 0, []));
        assertArraysEqual(cm.toLines(), [ "no source line" ]);
    }

    unittest
    {
        /* Test a single modification spanning two sections */
        auto cm = new ContentMapper();
        cm.m_mergeResultSections = MergeResultSections([ new ModifiableMergeResultSection(false,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          20, 21),
                                                         new ModifiableMergeResultSection(false,
                                                                                          12, 13,
                                                                                          12, 13,
                                                                                          12, 13,
                                                                                          22, 23)]);
        cm.applyModification(Modification(1, 2, 2, [ "edited 1", "edited 2" ]));
        assertArraysEqual(cm.toLines(), [ "original 10",
                                          "edited 1",
                                          "edited 2",
                                          "original 13" ]);

        // Check that the edited lines are added to the first section
        assertEqual(cm.m_mergeResultSections[0].getOutputSize(), 3);
        assertEqual(cm.m_mergeResultSections[1].getOutputSize(), 1);
    }

    unittest
    {
        /* Test a single modification spanning three sections */
        auto cm = new ContentMapper();
        cm.m_mergeResultSections = MergeResultSections([ new ModifiableMergeResultSection(false,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          10, 11,
                                                                                          20, 21),
                                                         new ModifiableMergeResultSection(false,
                                                                                          12, 13,
                                                                                          12, 13,
                                                                                          12, 13,
                                                                                          22, 23),
                                                         new ModifiableMergeResultSection(false,
                                                                                          14, 15,
                                                                                          14, 15,
                                                                                          14, 15,
                                                                                          24, 25)]);
        cm.applyModification(Modification(1, 4, 4, [ "edited 1", "edited 2", "edited 3", "edited 4" ]));
        assertArraysEqual(cm.toLines(), [ "original 10",
                                          "edited 1",
                                          "edited 2",
                                          "edited 3",
                                          "edited 4",
                                          "original 15" ]);

        // Check that the edited lines are added to the first section
        assertEqual(cm.m_mergeResultSections[0].getOutputSize(), 5);
        // Check that the middle non-difference section has 0 lines
        assertEqual(cm.m_mergeResultSections[1].getOutputSize(), 0);
        assertEqual(cm.m_mergeResultSections[2].getOutputSize(), 1);
    }

    ulong getNumberOfSections()
    {
        return m_mergeResultSections.length;
    }

    SectionInfo getSectionInfo(int sectionIndex)
    {
        MergeResultSection section = m_mergeResultSections[sectionIndex];
        SectionInfo info;
        info.inputPaneLineNumbers = section.m_diff3LineNumbers;
        info.isDifference = section.m_isDifference;

        // TODO: Optimize this to avoid looping over all sections every time section info is requested.
        int i;
        int firstLine = 0;
        for(i = 0; i < sectionIndex; i++)
        {
            firstLine += m_mergeResultSections[i].getOutputSize();
        }
        int lastLine = firstLine + m_mergeResultSections[i].getOutputSize() - 1;
        info.mergeResultPaneLineNumbers.firstLine = firstLine;
        info.mergeResultPaneLineNumbers.lastLine = lastLine;

        return info;
    }

    private int findNextSectionUsingPredicate(int sectionIndex, bool delegate(MergeResultSection s) pred)
    {
        sectionIndex++;
        while(sectionIndex < m_mergeResultSections.length && !pred(m_mergeResultSections[sectionIndex]))
        {
            sectionIndex++;
        }

        /* If we got to the end before we found another matching section, then return -1 */
        if(sectionIndex == m_mergeResultSections.length)
        {
            return -1;
        }
        else
        {
            return sectionIndex;
        }
    }

    int findNextDifference(int sectionIndex)
    {
        return findNextSectionUsingPredicate(sectionIndex, s => s.m_isDifference);
    }

    int findNextUnsolvedDifference(int sectionIndex)
    {
        return findNextSectionUsingPredicate(sectionIndex, s => !s.isSolved());
    }

    private int findPreviousSectionUsingPredicate(int sectionIndex, bool delegate(MergeResultSection s) pred)
    {
        sectionIndex--;
        while(sectionIndex >= 0 && !pred(m_mergeResultSections[sectionIndex]))
        {
            sectionIndex--;
        }

        /* If we got to the beginning before we found another matching section, then return -1 */
        return sectionIndex;
    }

    int findPreviousDifference(int sectionIndex)
    {
        return findPreviousSectionUsingPredicate(sectionIndex, s => s.m_isDifference);
    }

    int findPreviousUnsolvedDifference(int sectionIndex)
    {
        return findPreviousSectionUsingPredicate(sectionIndex, s => !s.isSolved());
    }

    bool allDifferencesSolved()
    {
        return all!((MergeResultSection s) { return s.isSolved(); } ) (m_mergeResultSections[]);
    }

    void toggleSectionSource(int sectionIndex, LineSource lineSource)
    {
        assert(sectionIndex >= 0);
        assert(sectionIndex < m_mergeResultSections.length);

        m_mergeResultSections[sectionIndex].toggle(lineSource);

        auto sectionInfo = getSectionInfo(sectionIndex);
        LineNumberRange range;
        range.firstLine = sectionInfo.mergeResultPaneLineNumbers.firstLine;
        range.lastLine = -1;
        m_linesChanged.emit(range);
    }

    string getEditedLine(int sectionIndex, int lineNumber)
    {
        return m_mergeResultSections[sectionIndex].getEditedLine(lineNumber);
    }

    int getContentHeight()
    {
        // TODO: Optimize this to avoid looping over all sections every time content height is requested
        int contentHeight = 0;
        foreach(section; m_mergeResultSections)
        {
            contentHeight += section.getOutputSize();
        }

        return contentHeight;
    }

    void connectLineChangeObserver(void delegate(LineNumberRange lines) d)
    {
        m_linesChanged.connect(d);
    }
}

/+
unittest
{
    /* Check if the original lines are returned if there are no modifications */
    auto mcp = new ModifiedContentProvider(lp);

    assertEqual(mcp.get(0), "line 0\n");
    assertEqual(mcp.get(10), "line 10\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1);
}

unittest
{
    /* Test with one modification that inserts more lines than it replaces */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(3, 1, 2, ["editedline 1\n", "editedline 2\n"]));
    assertEqual(mcp.get(2), "line 2\n");
    assertEqual(mcp.get(3), "editedline 1\n");
    assertEqual(mcp.get(4), "editedline 2\n");
    assertEqual(mcp.get(5), "line 4\n");
    assertEqual(mcp.get(6), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 1);
}

unittest
{
    /* Test adding one modification that inserts fewer lines than it replaces */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(3, 2, 1, ["editedline 1\n"]));
    assertEqual(mcp.get(2), "line 2\n");
    assertEqual(mcp.get(3), "editedline 1\n");
    assertEqual(mcp.get(4), "line 5\n");
    assertEqual(mcp.get(5), "line 6\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 1);
}

unittest
{
    /* Test adding a second modification that does not overlap after the first one */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(3, 1, 2, ["editedline a1\n", "editedline a2\n"]));
    mcp.applyModification(Modification(6, 1, 2, ["editedline b1\n", "editedline b2\n"]));

    assertEqual(mcp.get(2), "line 2\n");
    assertEqual(mcp.get(3), "editedline a1\n");
    assertEqual(mcp.get(4), "editedline a2\n");
    assertEqual(mcp.get(5), "line 4\n");
    assertEqual(mcp.get(6), "editedline b1\n");
    assertEqual(mcp.get(7), "editedline b2\n");
    assertEqual(mcp.get(8), "line 6\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 2);
}

unittest
{
    /* Test adding a third modification that does not overlap between the first and second one */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(2, 1, 2, ["editedline a1\n", "editedline a2\n"]));
    mcp.applyModification(Modification(7, 1, 2, ["editedline b1\n", "editedline b2\n"]));
    mcp.applyModification(Modification(5, 1, 2, ["editedline c1\n", "editedline c2\n"]));

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "editedline a1\n");
    assertEqual(mcp.get(3), "editedline a2\n");
    assertEqual(mcp.get(4), "line 3\n");
    assertEqual(mcp.get(5), "editedline c1\n");
    assertEqual(mcp.get(6), "editedline c2\n");
    assertEqual(mcp.get(7), "line 5\n");
    assertEqual(mcp.get(8), "editedline b1\n");
    assertEqual(mcp.get(9), "editedline b2\n");
    assertEqual(mcp.get(10), "line 7\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 3);
}

unittest
{
    /* Test adding a second modification that overlaps with the end of the first one */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(3, 1, 2, ["editedline a1\n", "editedline a2\n"]));
    mcp.applyModification(Modification(4, 1, 2, ["editedline b1\n", "editedline b2\n"]));

    assertEqual(mcp.get(2), "line 2\n");
    assertEqual(mcp.get(3), "editedline a1\n");
    assertEqual(mcp.get(4), "editedline b1\n");
    assertEqual(mcp.get(5), "editedline b2\n");
    assertEqual(mcp.get(6), "line 4\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 2);
}

unittest
{
    /* Test adding a second modification that overlaps with the beginning of the first one */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(3, 1, 2, ["editedline a1\n", "editedline a2\n"]));
    mcp.applyModification(Modification(2, 2, 2, ["editedline b1\n", "editedline b2\n"]));

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "editedline b1\n");
    assertEqual(mcp.get(3), "editedline b2\n");
    assertEqual(mcp.get(4), "editedline a2\n");
    assertEqual(mcp.get(5), "line 4\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 1);
}

unittest
{
    /* Test adding a second modification that overlaps with the middle of the first one */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(3, 1, 2, ["editedline a1\n", "editedline a2\n"]));
    mcp.applyModification(Modification(2, 4, 4, ["editedline b1\n", "editedline b2\n", "editedline b3\n", "editedline b4\n"]));

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "editedline b1\n");
    assertEqual(mcp.get(3), "editedline b2\n");
    assertEqual(mcp.get(4), "editedline b3\n");
    assertEqual(mcp.get(5), "editedline b4\n");
    assertEqual(mcp.get(6), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 1);
}

unittest
{
    /* Test adding a third modification that overlaps with the first and second modification */
    auto mcp = new ModifiedContentProvider(lp);

    mcp.applyModification(Modification(2, 1, 2, ["editedline a1\n", "editedline a2\n"]));
    mcp.applyModification(Modification(5, 1, 2, ["editedline b1\n", "editedline b2\n"]));
    mcp.applyModification(Modification(3, 3, 4, ["editedline c1\n", "editedline c2\n", "editedline c3\n", "editedline c4\n"]));

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "editedline a1\n");
    assertEqual(mcp.get(3), "editedline c1\n");
    assertEqual(mcp.get(4), "editedline c2\n");
    assertEqual(mcp.get(5), "editedline c3\n");
    assertEqual(mcp.get(6), "editedline c4\n");
    assertEqual(mcp.get(7), "editedline b2\n");
    assertEqual(mcp.get(8), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 3);
}

+/
