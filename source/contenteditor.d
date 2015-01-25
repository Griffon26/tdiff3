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
            mod.originalLineCount = lastPos.line - mod.firstLine;

            string modifiedLineAtBeginning;
            string modifiedLineAtEnd;

            /* If the selection starts at position 0 of a line then we don't
             * need to create an edited version of that line */
            if(firstPos.character != 0)
            {
                modifiedLineAtBeginning = m_le.get(firstPos.line)[0..firstPos.character];
                mod.editedLineCount++;
            }

            /* Only if the selection ends at position 0 of a line does that line stay the way it is */
            if(lastPos.character != 0)
            {
                modifiedLineAtEnd = m_le.get(lastPos.line)[lastPos.character..$];
                mod.originalLineCount++;
                mod.editedLineCount++;
            }

            if(mod.editedLineCount == 1)
            {
                mod.lines = [modifiedLineAtBeginning];
            }
            else if(mod.editedLineCount == 2)
            {
                mod.lines = [modifiedLineAtBeginning, modifiedLineAtEnd];
            }

            m_le.applyModification(mod);
        }
        else
        {
            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 1;
            mod.lines = ["deletes done\n"];
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
    /* Test if lines can be retrieved from ContentEditor */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    assertEqual(mcp.get(1), "line 1");
    assertEqual(mcp.get(2), "line 2");
}

unittest
{
    /* Test if a line can be deleted */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1");
    assertEqual(mcp.get(2), "deletes done\n");
    assertEqual(mcp.get(3), "line 3");
}

unittest
{
    /* Test if a line can be inserted */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.insertText("inserted");

    assertEqual(mcp.get(1), "line 1");
    assertEqual(mcp.get(2), "inserted");
    assertEqual(mcp.get(3), "line 3");
}

unittest
{
    /* Test if deleting a selection works */
    auto mcp = new ModifiedContentProvider(lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.moveTo(Position(4, 2), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1");
    assertEqual(mcp.get(2), "lin");
    assertEqual(mcp.get(3), "ne 4");
    assertEqual(mcp.get(4), "line 5");
}
