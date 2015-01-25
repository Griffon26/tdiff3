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

import std.algorithm;
import std.container;
import std.string;
import std.typecons;

import icontentprovider;
import ilineprovider;
import myassert;

struct Modification
{
    int firstLine;
    int originalLineCount;
    int editedLineCount;
    string[] lines;

    this(int firstLine, int originalLineCount, int editedLineCount, Array!string lines)
    {
        this.firstLine = firstLine;
        this.originalLineCount = originalLineCount;
        this.editedLineCount = editedLineCount;
    }

    this(int firstLine, int originalLineCount, int editedLineCount, string[] lines)
    {
        this.firstLine = firstLine;
        this.originalLineCount = originalLineCount;
        this.editedLineCount = editedLineCount;
        this.lines = lines;
    }
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

struct Position
{
    int line;
    int character;

    int opCmp(in Position rhs) const
    {
        return tuple(line, character).opCmp(tuple(rhs.line, rhs.character));
    }
}

class ModifiedContentProvider: IContentProvider
{
private:
    shared ILineProvider m_lp;
    DList!Modification m_modifications;

    enum RelativePosition
    {
        BEFORE,
        OVERLAPPING,
        AFTER
    }

public:
    this(shared ILineProvider lp)
    {
        m_lp = lp;
    }

    private RelativePosition checkRelativePosition(Modification existingModification, Modification newModification)
    {
        if(existingModification.firstLine + existingModification.editedLineCount < newModification.firstLine)
        {
            return RelativePosition.BEFORE;
        }
        else if(newModification.firstLine + newModification.originalLineCount < existingModification.firstLine)
        {
            return RelativePosition.AFTER;
        }
        else
        {
            return RelativePosition.OVERLAPPING;
        }
    }

    private static int calculateOverlap(int firstLine1, int numberOfLines1, int firstLine2, int numberOfLines2)
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

    private static Modification mergeModifications(Modification existingModification, Modification newModification)
    {
        Modification mergedModification;

        auto overlapWithExistingEditedLines = calculateOverlap(newModification.firstLine, newModification.originalLineCount,
                                                               existingModification.firstLine, existingModification.editedLineCount);

        mergedModification.firstLine = min(existingModification.firstLine, newModification.firstLine);
        mergedModification.originalLineCount = existingModification.originalLineCount +
                                              newModification.originalLineCount -
                                              overlapWithExistingEditedLines;
        mergedModification.editedLineCount = existingModification.editedLineCount +
                                            newModification.editedLineCount -
                                            overlapWithExistingEditedLines;

        int linesBefore = 0;
        int linesAfter = 0;

        int remainingEditedLines = existingModification.editedLineCount - overlapWithExistingEditedLines;

        if(remainingEditedLines > 0)
        {
            if(existingModification.firstLine < newModification.firstLine)
            {
                linesBefore = remainingEditedLines;
            }
            else if(existingModification.firstLine + existingModification.editedLineCount >
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
        mergedModification.lines[0..linesBefore] = existingModification.lines[0..linesBefore];
        mergedModification.lines[linesBefore..(linesBefore + newModification.lines.length)] = newModification.lines;
        mergedModification.lines[linesBefore + newModification.lines.length..$] = existingModification.lines[$ - linesAfter..$];

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
        auto mod = mergeModifications(Modification(2, 1, 2, ["a1", "a2"]),
                                      Modification(3, 2, 3, ["b1", "b2", "b3"]));
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
        auto mod = mergeModifications(Modification(2, 1, 2, ["a1", "a2"]),
                                      Modification(2, 2, 3, ["b1", "b2", "b3"]));
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
        auto mod = mergeModifications(Modification(2, 1, 3, ["a1", "a2", "a3"]),
                                      Modification(2, 1, 2, ["b1", "b2"]));
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
        auto mod = mergeModifications(Modification(3, 1, 2, ["a1", "a2"]),
                                      Modification(2, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(mod, Modification(2, 2, 4, ["b1", "b2", "b3", "a2"]));
    }


    void applyModification(Modification newtr)
    {
        DList!Modification updatedModifications;

        bool newtrInserted = false;
        auto trRange = m_modifications[];
        while(!trRange.empty)
        {
            switch(checkRelativePosition(trRange.front, newtr))
            {
            case RelativePosition.BEFORE:
                updatedModifications.insertBack(trRange.front);
                newtr.firstLine -= trRange.front.editedLineCount;
                newtr.firstLine += trRange.front.originalLineCount;
                break;
            case RelativePosition.OVERLAPPING:
                newtr = mergeModifications(trRange.front, newtr);
                break;
            case RelativePosition.AFTER:
                if(!newtrInserted)
                {
                    updatedModifications.insertBack(newtr);
                    newtrInserted = true;
                }
                updatedModifications.insertBack(trRange.front);
                break;
            default:
                assert(false);
            }
            trRange.popFront();
        }

        if(!newtrInserted)
        {
            updatedModifications.insertBack(newtr);
            newtrInserted = true;
        }

        m_modifications = updatedModifications;
    }




    /* IContentProvider methods */

    Nullable!string get(int line)
    {
        foreach(modification; m_modifications)
        {
            if(line >= modification.firstLine)
            {
                if(line < modification.firstLine + modification.editedLineCount)
                {
                    Nullable!string result;
                    result = modification.lines[line - modification.firstLine];
                    return result;
                }
                else
                {
                    line -= modification.editedLineCount;
                    line += modification.originalLineCount;
                }
            }
            else
            {
                return m_lp.get(line);
            }
        }
        return m_lp.get(line);
    }

    int getContentWidth()
    {
        /* TODO: implement */
        return 1000;
    }

    int getContentHeight()
    {
        /* TODO: implement */
        return 1000;
    }
}

version(unittest)
{
    synchronized class FakeLineProvider: ILineProvider
    {
        Nullable!string get(int line)
        {
            Nullable!string result;
            result = format("line %d", line);
            return result;
        }

        Nullable!string get(int firstLine, int lastLine)
        {
            Nullable!string result;
            result.nullify();
            return result;
        }

        int getLastLineNumber()
        {
            return 0;
        }
    }

    auto lp = new shared FakeLineProvider();
}

unittest
{
    /* Check if the original lines are returned if there are no modifications */
    auto le = new ModifiedContentProvider(lp);

    assertEqual(le.get(0), "line 0");
    assertEqual(le.get(10), "line 10");
}

unittest
{
    /* Test with one modification that inserts more lines than it replaces */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(3, 1, 2, ["editedline 1", "editedline 2"]));
    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline 1");
    assertEqual(le.get(4), "editedline 2");
    assertEqual(le.get(5), "line 4");
    assertEqual(le.get(6), "line 5");
}

unittest
{
    /* Test adding one modification that inserts fewer lines than it replaces */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(3, 2, 1, ["editedline 1"]));
    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline 1");
    assertEqual(le.get(4), "line 5");
    assertEqual(le.get(5), "line 6");
}

unittest
{
    /* Test adding a second modification that does not overlap after the first one */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyModification(Modification(6, 1, 2, ["editedline b1", "editedline b2"]));

    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline a1");
    assertEqual(le.get(4), "editedline a2");
    assertEqual(le.get(5), "line 4");
    assertEqual(le.get(6), "editedline b1");
    assertEqual(le.get(7), "editedline b2");
    assertEqual(le.get(8), "line 6");
}

unittest
{
    /* Test adding a third modification that does not overlap between the first and second one */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(2, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyModification(Modification(7, 1, 2, ["editedline b1", "editedline b2"]));
    le.applyModification(Modification(5, 1, 2, ["editedline c1", "editedline c2"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline a1");
    assertEqual(le.get(3), "editedline a2");
    assertEqual(le.get(4), "line 3");
    assertEqual(le.get(5), "editedline c1");
    assertEqual(le.get(6), "editedline c2");
    assertEqual(le.get(7), "line 5");
    assertEqual(le.get(8), "editedline b1");
    assertEqual(le.get(9), "editedline b2");
    assertEqual(le.get(10), "line 7");
}

unittest
{
    /* Test adding a second modification that overlaps with the end of the first one */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyModification(Modification(4, 1, 2, ["editedline b1", "editedline b2"]));

    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline a1");
    assertEqual(le.get(4), "editedline b1");
    assertEqual(le.get(5), "editedline b2");
    assertEqual(le.get(6), "line 4");
}

unittest
{
    /* Test adding a second modification that overlaps with the beginning of the first one */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyModification(Modification(2, 2, 2, ["editedline b1", "editedline b2"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline b1");
    assertEqual(le.get(3), "editedline b2");
    assertEqual(le.get(4), "editedline a2");
    assertEqual(le.get(5), "line 4");
}

unittest
{
    /* Test adding a second modification that overlaps with the middle of the first one */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyModification(Modification(2, 4, 4, ["editedline b1", "editedline b2", "editedline b3", "editedline b4"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline b1");
    assertEqual(le.get(3), "editedline b2");
    assertEqual(le.get(4), "editedline b3");
    assertEqual(le.get(5), "editedline b4");
    assertEqual(le.get(6), "line 5");
}

unittest
{
    /* Test adding a third modification that overlaps with the first and second modification */
    auto le = new ModifiedContentProvider(lp);

    le.applyModification(Modification(2, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyModification(Modification(5, 1, 2, ["editedline b1", "editedline b2"]));
    le.applyModification(Modification(3, 3, 4, ["editedline c1", "editedline c2", "editedline c3", "editedline c4"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline a1");
    assertEqual(le.get(3), "editedline c1");
    assertEqual(le.get(4), "editedline c2");
    assertEqual(le.get(5), "editedline c3");
    assertEqual(le.get(6), "editedline c4");
    assertEqual(le.get(7), "editedline b2");
    assertEqual(le.get(8), "line 5");
}


