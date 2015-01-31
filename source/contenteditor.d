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

import common;
import modifiedcontentprovider;
import myassert;

class ContentEditor
{
private:
    bool m_selectionActive;
    Position m_selectionBegin;
    Position m_currentPos; /* also the end of the selection */

    string m_copyPasteBuffer;
    ModifiedContentProvider m_le;

public:
    this(ModifiedContentProvider le)
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

            auto mod = Modification();
            mod.firstLine = firstPos.line;
            mod.originalLineCount = lastPos.line - mod.firstLine + 1;

            string modifiedLineAtBeginning;
            string modifiedLineAtEnd;

            /* If the selection starts at position 0 of a line then we don't
             * need to create an edited version of that line */
            if(firstPos.character != 0)
            {
                modifiedLineAtBeginning = m_le.get(firstPos.line).substringColumns(0, firstPos.character, true);
            }

            /* If the selection ends at the last position of a line, nothing remains to be added to the edited line */
            auto lastLineColumns = m_le.get(lastPos.line).lengthInColumns;
            if(lastPos.character != lastLineColumns - 1)
            {
                modifiedLineAtEnd = m_le.get(lastPos.line).substringColumns(lastPos.character + 1, lastLineColumns, true);
            }

            if(modifiedLineAtBeginning.length == 0 && modifiedLineAtEnd.length == 0)
            {
                mod.editedLineCount = 0;
            }
            else
            {
                /* If the end of the line was completely deleted, then the next line will move up */
                if(modifiedLineAtEnd.length == 0)
                {
                    modifiedLineAtEnd = m_le.get(lastPos.line + 1);
                    mod.originalLineCount++;
                }

                mod.lines = [modifiedLineAtBeginning ~ modifiedLineAtEnd];
                mod.editedLineCount = 1;
            }

            m_le.applyModification(mod);
        }
        else
        {
            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 1;

            auto originalLine = m_le.get(m_currentPos.line);
            auto originalLineColumns = originalLine.lengthInColumns;

            if(m_currentPos.character == originalLineColumns - 1)
            {
                mod.lines = [ originalLine.substringColumns(0, m_currentPos.character, true) ~ m_le.get(m_currentPos.line + 1) ];
                mod.originalLineCount = 2;
            }
            else
            {
                mod.lines = [ originalLine.substringColumns(0, m_currentPos.character, true) ~ originalLine.substringColumns(m_currentPos.character + 1, originalLineColumns, true) ];
            }
            m_le.applyModification(mod);
        }
    }
    void insertText(string fragment)
    {
        auto mod = Modification();
        mod.firstLine = m_currentPos.line;
        mod.originalLineCount = 1;
        mod.editedLineCount = 1;
        mod.lines = [fragment];
        m_le.applyModification(mod);
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
}

unittest
{
    /* Test if a character can be deleted */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "lin 2\n");
    assertEqual(mcp.get(3), "line 3\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1);
}

unittest
{
    /* Test if a newline can be deleted */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 6), false);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "line 2line 3\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 1);
}

unittest
{
    /* Test if a line can be inserted */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.insertText("inserted\n");

    assertEqual(mcp.get(1), "line 1\n");
    // TODO: fails until insertText is properly implemented
    //assertEqual(mcp.get(2), "inserted\n");
    //assertEqual(mcp.get(3), "line 2\n");
    //assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 + 1);
}

unittest
{
    /* Test deleting a selection at the start of the line */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 0), false);
    editor.moveTo(Position(2, 2), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "e 2\n");
    assertEqual(mcp.get(3), "line 3\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1);
}

unittest
{
    /* Test deleting a selection in the middle of a line */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 1), false);
    editor.moveTo(Position(2, 2), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "le 2\n");
    assertEqual(mcp.get(3), "line 3\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1);
}

unittest
{
    /* Test deleting a selection upto the end of a line */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 2), false);
    editor.moveTo(Position(2, 6), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "liline 3\n");
    assertEqual(mcp.get(3), "line 4\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 1);
}

unittest
{
    /* Test deleting a selection upto the end of another line */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 2), false);
    editor.moveTo(Position(3, 6), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "liline 4\n");
    assertEqual(mcp.get(3), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 2);
}

unittest
{
    /* Test deleting a selection from the middle of one line to the middle of another, when lines are adjacent */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.moveTo(Position(3, 1), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "linne 3\n");
    assertEqual(mcp.get(3), "line 4\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 1);
}

unittest
{
    /* Test deleting a selection from the middle of one line to the middle of another, with lines in between */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.moveTo(Position(4, 1), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "linne 4\n");
    assertEqual(mcp.get(3), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 2);
}

unittest
{
    /* Test deleting a selection from the start of one line to the middle of another, when lines are adjacent */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 0), false);
    editor.moveTo(Position(3, 1), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "ne 3\n");
    assertEqual(mcp.get(3), "line 4\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 1);
}

unittest
{
    /* Test deleting a selection from the start of one line to the middle of another, with lines in between */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 0), false);
    editor.moveTo(Position(4, 1), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "ne 4\n");
    assertEqual(mcp.get(3), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 2);
}

unittest
{
    /* Test deleting a selection from the middle of one line to the start of another, when lines are adjacent */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.moveTo(Position(3, 0), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "linine 3\n");
    assertEqual(mcp.get(3), "line 4\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 1);
}

unittest
{
    /* Test deleting a selection from the middle of one line to the start of another, with lines in between */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.moveTo(Position(4, 0), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "linine 4\n");
    assertEqual(mcp.get(3), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 2);
}

