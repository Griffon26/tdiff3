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
module contenteditor;

import std.algorithm;

import common;
import contentmapper;
import mergeresultcontentprovider;
import myassert;
import stringcolumns;


/**
 * The ContentEditor is responsible for translating editing commands received
 * from the Ui into modifications and send them to the ContentMapper.  It is
 * also responsible for maintaining the cursor position and selection state.
 *
 * <object data="../uml/contenteditor.svg" type="image/svg+xml"></object>
 */
/*
 * @startuml
 * hide circle
 * skinparam minClassWidth 70
 * skinparam classArrowFontSize 8
 * class Ui --> ContentEditor: sends editing commands\nsends cursor navigation commands\ngets cursor position
 * ContentEditor --> ContentMapper: applies modifications
 * ContentEditor --> ILineProvider: gets line
 *
 * url of Ui is [[../ui/Ui.html]]
 * url of ILineProvider is [[../ilineprovider/ILineProvider.html]]
 * url of ContentMapper is [[../contentmapper/ContentMapper.html]]
 * @enduml
 */
class ContentEditor
{
private:
    bool m_selectionActive;
    Position m_selectionBegin;
    Position m_currentPos; /* also the end of the selection */

    string m_copyPasteBuffer;
    MergeResultContentProvider m_mcp;
    ContentMapper m_contentMapper;

    bool m_outputFocusChanged;
    Position m_outputFocusPosition;

public:
    enum Movement
    {
        UP,
        DOWN,
        LEFT,
        RIGHT,
        LINEHOME,
        LINEEND,
        FILEHOME,
        FILEEND
    }

    this(MergeResultContentProvider mergeResultContentProvider, ContentMapper contentMapper)
    {
        m_mcp = mergeResultContentProvider;
        m_contentMapper = contentMapper;
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
            if(newPos != m_currentPos)
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
    }

    bool move(Movement mv, bool withSelection)
    {
        Position oldPos = m_currentPos;
        Position newPos = m_currentPos;

        switch(mv)
        {
        case Movement.RIGHT:
            auto currentChar = m_mcp.getLineWithType(m_currentPos.line).text.toStringColumns(m_currentPos.character).currentChar;
            if(currentChar.nextColumn !is null)
            {
                newPos.character = currentChar.nextColumn.column;
            }
            break;
        case Movement.LEFT:
            auto currentChar = m_mcp.getLineWithType(m_currentPos.line).text.toStringColumns(m_currentPos.character).currentChar;
            if(currentChar.prevColumn !is null)
            {
                newPos.character = currentChar.prevColumn.column;
            }
            break;
        case Movement.UP:
            if(m_currentPos.line > 0)
            {
                newPos.line--;
                auto currentChar = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_currentPos.character).currentChar;
                newPos.character = currentChar.column;
            }
            break;
        case Movement.DOWN:
            if(m_currentPos.line < m_mcp.getContentHeight() - 1)
            {
                newPos.line++;
                auto currentChar = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_currentPos.character).currentChar;
                newPos.character = currentChar.column;
            }
            break;
        case Movement.LINEHOME:
            newPos.character = 0;
            break;
        case Movement.LINEEND:
            newPos.character = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_currentPos.character).lastChar.column;
            break;
        case Movement.FILEHOME:
            newPos.character = 0;
            newPos.line = 0;
            break;
        case Movement.FILEEND:
            newPos.character = 0;
            newPos.line = m_mcp.getContentHeight() - 1;
            break;
        default:
            assert(false);
        }

        moveTo(newPos, withSelection);

        updateOutputFocusPosition(newPos);

        return newPos != oldPos;
    }

    bool moveDistance(Movement mv, int distance, bool withSelection)
    {
        Position oldPos = m_currentPos;
        Position newPos = m_currentPos;

        switch(mv)
        {
        case Movement.UP:
            newPos.line = max(0, m_currentPos.line - distance);
            break;
        case Movement.DOWN:
            newPos.line = min(m_mcp.getContentHeight() - 1, m_currentPos.line + distance);
            break;
        default:
            assert(false);
        }

        moveTo(newPos, withSelection);

        updateOutputFocusPosition(newPos);

        return newPos != oldPos;
    }

    Position getCursorPosition()
    {
        return m_currentPos;
    }

    /**
     * the focus position represents the position in input and output content
     * that should be moved into view. If the last operation was an edit, then
     * this is the cursor position. If the last operation was a change in
     * selected section, then it's the first character in the section.
     * Only when the focus position changes should the scroll position be
     * updated.
     */
    private void updateOutputFocusPosition(Position pos)
    {
        m_outputFocusChanged = true;
        m_outputFocusPosition = pos;
    }

    bool outputFocusNeedsUpdate()
    {
        return m_outputFocusChanged;
    }

    Position getOutputFocusPosition()
    {
        m_outputFocusChanged = false;
        return m_outputFocusPosition;
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
                auto originalLine = m_mcp.get(firstPos.line);
                auto firstDeletedChar = originalLine.toStringColumns(firstPos.character).currentChar;
                modifiedLineAtBeginning = originalLine[0..firstDeletedChar.index];
            }

            /* If the selection ends at the last position of a line, nothing remains to be added to the edited line */
            auto lastLine = m_mcp.get(lastPos.line);
            auto lastDeletedChar = lastLine.toStringColumns(lastPos.character).currentChar;
            if(lastDeletedChar.nextChar !is null)
            {
                modifiedLineAtEnd = lastLine[lastDeletedChar.nextChar.index..$];
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
                    modifiedLineAtEnd = m_mcp.get(lastPos.line + 1);
                    mod.originalLineCount++;
                }

                mod.lines = [modifiedLineAtBeginning ~ modifiedLineAtEnd];
                mod.editedLineCount = 1;
            }

            m_contentMapper.applyModification(mod);
        }
        else
        {
            bool applyModification = false;
            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 1;

            auto originalLine = m_mcp.getLineWithType(m_currentPos.line);

            auto currentChar = originalLine.text.toStringColumns(m_currentPos.character).currentChar;

            /* Don't delete anything when we're in an uneditable line */
            if(originalLine.type != MergeResultContentProvider.LineType.NORMAL)
            {
                /* Do nothing */
                applyModification = false;
            }
            /* If we're just before the newline */
            else if(currentChar.nextChar is null)
            {
                /* ... and we're also at the beginning of the line... */
                if(currentChar.prevChar is null)
                {
                    /* ... then delete this line itself */
                    mod.editedLineCount = 0;
                    applyModification = true;
                }
                else
                {
                    /* ... otherwise if the next line is not editable ... */
                    auto nextLine = m_mcp.getLineWithType(m_currentPos.line + 1);
                    if(nextLine.type != MergeResultContentProvider.LineType.NORMAL)
                    {
                        /* ... then refuse to delete the newline */
                        applyModification = false;
                    }
                    else
                    {
                        /* ... otherwise stick the next line onto the end of the current one */
                        mod.lines = [ originalLine.text[0..(currentChar.index)] ~ nextLine.text];
                        mod.originalLineCount = 2;
                        applyModification = true;
                    }
                }
            }
            else
            {
                mod.lines = [ originalLine.text[0..(currentChar.index)] ~ originalLine.text[(currentChar.nextChar.index)..$] ];
                applyModification = true;
            }

            if(applyModification)
            {
                m_contentMapper.applyModification(mod);
            }

        }
    }
    void insertText(string fragment)
    {
        auto mod = Modification();
        mod.firstLine = m_currentPos.line;
        mod.originalLineCount = 1;
        mod.editedLineCount = 1;
        mod.lines = [fragment];
        m_contentMapper.applyModification(mod);
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

/+
unittest
{
    /* Test if a character can be deleted */
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
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
    auto mcp = new MergeResultContentProvider(lp, lp, lp);
    auto editor = new ContentEditor(mcp);

    editor.moveTo(Position(2, 3), false);
    editor.moveTo(Position(4, 0), true);
    editor.delete_();

    assertEqual(mcp.get(1), "line 1\n");
    assertEqual(mcp.get(2), "linine 4\n");
    assertEqual(mcp.get(3), "line 5\n");
    assertEqual(mcp.getContentHeight(), lp.getLastLineNumber() + 1 - 2);
}
+/
