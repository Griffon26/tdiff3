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
import std.conv;
import std.stdio;
import std.string;
import std.typecons;

import deimos.ncurses.curses;

import icontentprovider;
import ilineprovider;
import inputpane;
import myassert;

struct Translation
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
    auto tr = Translation(1, 2, 3, ["one", "two"]);

    assertEqual(tr.firstLine, 1);
    assertEqual(tr.originalLineCount, 2);
    assertEqual(tr.editedLineCount, 3);
    assertEqual(tr.lines[0], "one");
    assertEqual(tr.lines[1], "two");
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

class LineEditable
{
private:
    shared ILineProvider m_lp;
    DList!Translation m_translations;

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

    private RelativePosition checkRelativePosition(Translation existingTranslation, Translation newTranslation)
    {
        if(existingTranslation.firstLine + existingTranslation.editedLineCount < newTranslation.firstLine)
        {
            return RelativePosition.BEFORE;
        }
        else if(newTranslation.firstLine + newTranslation.originalLineCount < existingTranslation.firstLine)
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

    private static Translation mergeTranslations(Translation existingTranslation, Translation newTranslation)
    {
        Translation mergedTranslation;

        auto overlapWithExistingEditedLines = calculateOverlap(newTranslation.firstLine, newTranslation.originalLineCount,
                                                               existingTranslation.firstLine, existingTranslation.editedLineCount);

        mergedTranslation.firstLine = min(existingTranslation.firstLine, newTranslation.firstLine);
        mergedTranslation.originalLineCount = existingTranslation.originalLineCount +
                                              newTranslation.originalLineCount -
                                              overlapWithExistingEditedLines;
        mergedTranslation.editedLineCount = existingTranslation.editedLineCount +
                                            newTranslation.editedLineCount -
                                            overlapWithExistingEditedLines;

        int linesBefore = 0;
        int linesAfter = 0;

        int remainingEditedLines = existingTranslation.editedLineCount - overlapWithExistingEditedLines;

        if(remainingEditedLines > 0)
        {
            if(existingTranslation.firstLine < newTranslation.firstLine)
            {
                linesBefore = remainingEditedLines;
            }
            else if(existingTranslation.firstLine + existingTranslation.editedLineCount >
                    newTranslation.firstLine + newTranslation.originalLineCount)
            {
                linesAfter = remainingEditedLines;
            }
            else
            {
                assert(false);
            }
        }

        mergedTranslation.lines.length = linesBefore + newTranslation.lines.length + linesAfter;
        mergedTranslation.lines[0..linesBefore] = existingTranslation.lines[0..linesBefore];
        mergedTranslation.lines[linesBefore..(linesBefore + newTranslation.lines.length)] = newTranslation.lines;
        mergedTranslation.lines[linesBefore + newTranslation.lines.length..$] = existingTranslation.lines[$ - linesAfter..$];

        return mergedTranslation;
    }

    unittest
    {
        /* Check merge of translation that overlaps with end of existing translation */

        // 1  1       1
        // 2  a1      a1
        // 3  a2  b1  b1
        // 4  3   b2  b2
        // 5  4   b3  b3
        // 6  5       4
        auto tr = mergeTranslations(Translation(2, 1, 2, ["a1", "a2"]),
                                    Translation(3, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(tr, Translation(2, 2, 4, ["a1", "b1", "b2", "b3"]));
    }

    unittest
    {
        /* Check merge of translation that overlaps with all of existing translation */

        // 1  1       1
        // 2  a1  b1  b1
        // 3  a2  b2  b2
        // 4  3   b3  b3
        // 5  4       3
        auto tr = mergeTranslations(Translation(2, 1, 2, ["a1", "a2"]),
                                    Translation(2, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(tr, Translation(2, 1, 3, ["b1", "b2", "b3"]));
    }

    unittest
    {
        /* Check merge of translation that overlaps with beginning of existing translation */

        // 1  1       1
        // 2  a1  b1  b1
        // 3  a2  b2  b2
        // 4  a3      a2
        // 5  3       a3
        // 6  4       3
        auto tr = mergeTranslations(Translation(2, 1, 3, ["a1", "a2", "a3"]),
                                    Translation(2, 1, 2, ["b1", "b2"]));
        assertEqual(tr, Translation(2, 1, 4, ["b1", "b2", "a2", "a3"]));
    }

    unittest
    {
        /* Check merge of translation that starts before and overlaps with beginning of existing translation */

        // 1  1       1
        // 2  2   b1  b1
        // 3  a1  b2  b2
        // 4  a2  b3  b3
        // 5  4       a2
        // 6  5       4
        auto tr = mergeTranslations(Translation(3, 1, 2, ["a1", "a2"]),
                                    Translation(2, 2, 3, ["b1", "b2", "b3"]));
        assertEqual(tr, Translation(2, 2, 4, ["b1", "b2", "b3", "a2"]));
    }


    void applyEdit(Translation newtr)
    {
        DList!Translation updatedTranslations;

        bool newtrInserted = false;
        auto trRange = m_translations[];
        while(!trRange.empty)
        {
            switch(checkRelativePosition(trRange.front, newtr))
            {
            case RelativePosition.BEFORE:
                updatedTranslations.insertBack(trRange.front);
                newtr.firstLine -= trRange.front.editedLineCount;
                newtr.firstLine += trRange.front.originalLineCount;
                break;
            case RelativePosition.OVERLAPPING:
                newtr = mergeTranslations(trRange.front, newtr);
                break;
            case RelativePosition.AFTER:
                if(!newtrInserted)
                {
                    updatedTranslations.insertBack(newtr);
                    newtrInserted = true;
                }
                updatedTranslations.insertBack(trRange.front);
                break;
            default:
                assert(false);
            }
            trRange.popFront();
        }

        if(!newtrInserted)
        {
            updatedTranslations.insertBack(newtr);
            newtrInserted = true;
        }

        m_translations = updatedTranslations;
    }




    /* ILineProvider methods */

    Nullable!string get(int line)
    {
        foreach(translation; m_translations)
        {
            if(line >= translation.firstLine)
            {
                if(line < translation.firstLine + translation.editedLineCount)
                {
                    Nullable!string result;
                    result = translation.lines[line - translation.firstLine];
                    return result;
                }
                else
                {
                    line -= translation.editedLineCount;
                    line += translation.originalLineCount;
                }
            }
            else
            {
                return m_lp.get(line);
            }
        }
        return m_lp.get(line);
    }

    Nullable!string get(int firstLine, int lastLine)
    {
        Nullable!string result;
        result.nullify();
        return result;
    }

    int getLastLineNumber()
    {
        /* TODO: implement */
        return 0;
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
    /* Check if the original lines are returned if there are no translations */
    auto le = new LineEditable(lp);

    assertEqual(le.get(0), "line 0");
    assertEqual(le.get(10), "line 10");
}

unittest
{
    /* Test with one translation that inserts more lines than it replaces */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(3, 1, 2, ["editedline 1", "editedline 2"]));
    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline 1");
    assertEqual(le.get(4), "editedline 2");
    assertEqual(le.get(5), "line 4");
    assertEqual(le.get(6), "line 5");
}

unittest
{
    /* Test adding one translation that inserts fewer lines than it replaces */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(3, 2, 1, ["editedline 1"]));
    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline 1");
    assertEqual(le.get(4), "line 5");
    assertEqual(le.get(5), "line 6");
}

unittest
{
    /* Test adding a second translation that does not overlap after the first one */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyEdit(Translation(6, 1, 2, ["editedline b1", "editedline b2"]));

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
    /* Test adding a third translation that does not overlap between the first and second one */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(2, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyEdit(Translation(7, 1, 2, ["editedline b1", "editedline b2"]));
    le.applyEdit(Translation(5, 1, 2, ["editedline c1", "editedline c2"]));

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
    /* Test adding a second translation that overlaps with the end of the first one */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyEdit(Translation(4, 1, 2, ["editedline b1", "editedline b2"]));

    assertEqual(le.get(2), "line 2");
    assertEqual(le.get(3), "editedline a1");
    assertEqual(le.get(4), "editedline b1");
    assertEqual(le.get(5), "editedline b2");
    assertEqual(le.get(6), "line 4");
}

unittest
{
    /* Test adding a second translation that overlaps with the beginning of the first one */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyEdit(Translation(2, 2, 2, ["editedline b1", "editedline b2"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline b1");
    assertEqual(le.get(3), "editedline b2");
    assertEqual(le.get(4), "editedline a2");
    assertEqual(le.get(5), "line 4");
}

unittest
{
    /* Test adding a second translation that overlaps with the middle of the first one */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(3, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyEdit(Translation(2, 4, 4, ["editedline b1", "editedline b2", "editedline b3", "editedline b4"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline b1");
    assertEqual(le.get(3), "editedline b2");
    assertEqual(le.get(4), "editedline b3");
    assertEqual(le.get(5), "editedline b4");
    assertEqual(le.get(6), "line 5");
}

unittest
{
    /* Test adding a third translation that overlaps with the first and second translation */
    auto le = new LineEditable(lp);

    le.applyEdit(Translation(2, 1, 2, ["editedline a1", "editedline a2"]));
    le.applyEdit(Translation(5, 1, 2, ["editedline b1", "editedline b2"]));
    le.applyEdit(Translation(3, 3, 4, ["editedline c1", "editedline c2", "editedline c3", "editedline c4"]));

    assertEqual(le.get(1), "line 1");
    assertEqual(le.get(2), "editedline a1");
    assertEqual(le.get(3), "editedline c1");
    assertEqual(le.get(4), "editedline c2");
    assertEqual(le.get(5), "editedline c3");
    assertEqual(le.get(6), "editedline c4");
    assertEqual(le.get(7), "editedline b2");
    assertEqual(le.get(8), "line 5");
}

class EditableContentProvider: IContentProvider
{
private:
    bool m_selectionActive;
    Position m_selectionBegin;
    Position m_currentPos; /* also the end of the selection */

    string m_copyPasteBuffer;
    LineEditable m_le;

public:
    this(LineEditable le)
    {
        m_le = le;
    }

    /* Editor operations */

    void moveTo(Position newPos, bool withSelection)
    {
        if(!withSelection)
        {
            m_selectionActive = false;
            m_currentPos = newPos;
        }
        else
        {
            if(!m_selectionActive)
            {
                m_selectionActive = true;
                m_selectionBegin = m_currentPos;
            }
            m_currentPos = newPos;

            /* Reducing the selection to 0 chars destroys it */
            if(m_selectionBegin == m_currentPos)
            {
                m_selectionActive = false;
            }
        }
    }
    void delete_()
    {
        if(m_selectionActive)
        {
            auto firstPos = min(m_selectionBegin, m_currentPos);
            auto lastPos = max(m_selectionBegin, m_currentPos);

            writefln("%s", firstPos);
            writefln("%s", lastPos);

            auto tr = Translation();
            tr.firstLine = firstPos.line;
            tr.originalLineCount = lastPos.line - tr.firstLine;

            string modifiedLineAtBeginning;
            string modifiedLineAtEnd;

            /* If the selection starts at position 0 of a line then we don't
             * need to create an edited version of that line */
            if(firstPos.character != 0)
            {
                modifiedLineAtBeginning = m_le.get(firstPos.line)[0..firstPos.character];
                tr.editedLineCount++;
            }

            /* Only if the selection ends at position 0 of a line does that line stay the way it is */
            if(lastPos.character != 0)
            {
                modifiedLineAtEnd = m_le.get(lastPos.line)[lastPos.character..$];
                tr.originalLineCount++;
                tr.editedLineCount++;
            }

            if(tr.editedLineCount == 1)
            {
                tr.lines = [modifiedLineAtBeginning];
            }
            else if(tr.editedLineCount == 2)
            {
                tr.lines = [modifiedLineAtBeginning, modifiedLineAtEnd];
            }

            m_le.applyEdit(tr);
        }
        else
        {
            auto tr = Translation();
            tr.firstLine = m_currentPos.line;
            tr.originalLineCount = 1;
            tr.editedLineCount = 1;
            tr.lines = ["deletes done\n"];
            m_le.applyEdit(tr);
        }
    }
    void insertText(string fragment)
    {
        auto tr = Translation();
        tr.firstLine = m_currentPos.line;
        tr.originalLineCount = 1;
        tr.editedLineCount = 1;
        tr.lines = [fragment];
        m_le.applyEdit(tr);
    }
    void cut()
    {
        copy();
        delete_();
    }
    void copy()
    {
        //m_copyPasteBuffer = createFragmentFromSelection();
    }
    void paste()
    {
        insertText(m_copyPasteBuffer);
    }

    /* IContentProvider methods */

    Nullable!string get(int line)
    {
        return m_le.get(line);
    }

    int getContentWidth()
    {
        /* TODO: fix */
        return 1000;
    }

    int getContentHeight()
    {
        /* TODO: fix */
        return 1000;
    }
}

unittest
{
    /* Test if lines can be retrieved from EditableContentProvider */
    auto le = new LineEditable(lp);
    auto ec = new EditableContentProvider(le);

    assertEqual(ec.get(1), "line 1");
    assertEqual(ec.get(2), "line 2");
}

unittest
{
    /* Test if a line can be deleted */
    auto le = new LineEditable(lp);
    auto ec = new EditableContentProvider(le);

    ec.moveTo(Position(2, 3), false);
    ec.delete_();

    assertEqual(ec.get(1), "line 1");
    assertEqual(ec.get(2), "deletes done");
    assertEqual(ec.get(3), "line 3");
}

unittest
{
    /* Test if a line can be inserted */
    auto le = new LineEditable(lp);
    auto ec = new EditableContentProvider(le);

    ec.moveTo(Position(2, 3), false);
    ec.insertText("inserted");

    assertEqual(ec.get(1), "line 1");
    assertEqual(ec.get(2), "inserted");
    assertEqual(ec.get(3), "line 3");
}

unittest
{
    /* Test if deleting a selection works */
    auto le = new LineEditable(lp);
    auto ec = new EditableContentProvider(le);

    ec.moveTo(Position(2, 3), false);
    ec.moveTo(Position(4, 2), true);
    ec.delete_();

    assertEqual(ec.get(1), "line 1");
    assertEqual(ec.get(2), "lin");
    assertEqual(ec.get(3), "ne 4");
    assertEqual(ec.get(4), "line 5");
}

class OutputPane: InputPane
{
private:
    EditableContentProvider m_ecp;

    int m_cursor_x;
    int m_cursor_y;

public:
    this(int x, int y,
         int width, int height,
         EditableContentProvider ecp)
    {
        super(x, y, width, height, 100, 100, ecp);
        m_ecp = ecp;
    }

    bool handleKeyboardInput(int ch)
    {
        bool handled = true;

        switch(ch)
        {
        case KEY_LEFT:
            m_cursor_x--;
            m_ecp.moveTo(Position(m_cursor_y, m_cursor_x), false);
            break;
        case KEY_RIGHT:
            m_cursor_x++;
            m_ecp.moveTo(Position(m_cursor_y, m_cursor_x), false);
            break;
        case KEY_UP:
            m_cursor_y--;
            m_ecp.moveTo(Position(m_cursor_y, m_cursor_x), false);

            auto distanceOffScreen = m_scrollPositionY - m_cursor_y;
            if(distanceOffScreen > 0)
            {
                scrollY(-distanceOffScreen);
            }
            break;
        case KEY_DOWN:
            m_cursor_y++;
            m_ecp.moveTo(Position(m_cursor_y, m_cursor_x), false);

            auto distanceOffScreen = m_cursor_y - m_height - m_scrollPositionY + 1;
            if(distanceOffScreen > 0)
            {
                scrollY(distanceOffScreen);
            }
            break;
        case KEY_DC:
            m_ecp.delete_();
            drawMissingLines(0, 0, m_height);
            break;
        default:
            handled = false;
            break;
        }

        return handled;
    }

    /* Redraws content */
    override void redraw()
    {
        wmove(m_pad, m_cursor_y - m_scrollPositionY, m_cursor_x);
        super.redraw();
    }
}

