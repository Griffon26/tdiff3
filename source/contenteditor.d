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

import core.stdc.locale;
import std.algorithm;
import std.conv;
import std.typecons;

import common;
import contentmapper;
import mergeresultcontentprovider;
import myassert;
import stringcolumns;
import unittestdata;


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
    /**
     * The preferred column stores the x position of the cursor after every
     * horizontal movement of the cursor.  When moving the cursor vertically
     * the cursor is positioned as close to the preferred column as the length
     * of the current line will allow. This allows one to move from one long
     * line over empty lines to another long line without losing the horizontal
     * cursor position.
     */
    int m_preferredColumn;

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
                m_preferredColumn = newPos.character;
            }
            break;
        case Movement.LEFT:
            auto currentChar = m_mcp.getLineWithType(m_currentPos.line).text.toStringColumns(m_currentPos.character).currentChar;
            if(currentChar.prevColumn !is null)
            {
                newPos.character = currentChar.prevColumn.column;
                m_preferredColumn = newPos.character;
            }
            break;
        case Movement.UP:
            if(m_currentPos.line > 0)
            {
                newPos.line--;
                auto currentChar = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_preferredColumn).currentChar;
                newPos.character = currentChar.column;
            }
            break;
        case Movement.DOWN:
            if(m_currentPos.line < m_mcp.getContentHeight() - 1)
            {
                newPos.line++;
                auto currentChar = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_preferredColumn).currentChar;
                newPos.character = currentChar.column;
            }
            break;
        case Movement.LINEHOME:
            newPos.character = 0;
            m_preferredColumn = newPos.character;
            break;
        case Movement.LINEEND:
            newPos.character = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_currentPos.character).lastChar.column;
            m_preferredColumn = newPos.character;
            break;
        case Movement.FILEHOME:
            newPos.character = 0;
            newPos.line = 0;
            m_preferredColumn = newPos.character;
            break;
        case Movement.FILEEND:
            newPos.character = 0;
            newPos.line = m_mcp.getContentHeight() - 1;
            m_preferredColumn = newPos.character;
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
            auto currentChar = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_preferredColumn).currentChar;
            newPos.character = currentChar.column;
            break;
        case Movement.DOWN:
            newPos.line = min(m_mcp.getContentHeight() - 1, m_currentPos.line + distance);
            auto currentChar = m_mcp.getLineWithType(newPos.line).text.toStringColumns(m_preferredColumn).currentChar;
            newPos.character = currentChar.column;
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

    void backspace()
    {
        if(m_selectionActive)
        {
            delete_();
        }
        else
        {
            bool applyModification = false;
            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 1;

            auto currentLine = m_mcp.getLineWithType(m_currentPos.line);
            auto currentChar = currentLine.text.toStringColumns(m_currentPos.character).currentChar;

            /* If we're at the start of a line, then it depends on the previous line if we can backspace */
            if(currentChar.prevChar is null)
            {
                auto prevLine = m_mcp.getLineWithType(m_currentPos.line - 1);

                /* If the previous line is a normal line... */
                if(prevLine.type == LineType.NORMAL)
                {
                    /* ... and if it's empty ... */
                    if(prevLine.text == "\n")
                    {
                        /* ... then delete that previous line */
                        mod.firstLine = m_currentPos.line - 1;
                        mod.editedLineCount = 0;
                        applyModification = true;

                        m_currentPos.line--;
                    }
                    /* ... but if the previous line is not empty we can only append this one if this one is a normal one */
                    else if(currentLine.type == LineType.NORMAL)
                    {
                        /* ... otherwise stick the current line at the end of the previous one */
                        auto lastCharOfPrevLine = prevLine.text.toStringColumns(0).lastChar;
                        mod.firstLine = m_currentPos.line - 1;
                        mod.originalLineCount = 2;
                        mod.lines = [ prevLine.text[0..lastCharOfPrevLine.index] ~ currentLine.text ];
                        applyModification = true;

                        m_currentPos.line--;
                        m_currentPos.character = lastCharOfPrevLine.column;
                    }
                    else
                    {
                        /* ... otherwise we ignore the backspace */
                        applyModification = false;
                    }
                }
                else
                {
                    /* ... otherwise ignore the backspace */
                    applyModification = false;
                }
            }
            /* ... if we're not at the start of a line ... */
            else
            {
                /* ... and the line is a normal one ... */
                if(currentLine.type == LineType.NORMAL)
                {
                    /* ... then we remove the previous char */
                    auto deletedChar = currentChar.prevChar;
                    mod.lines = [ currentLine.text[0..deletedChar.index] ~ currentLine.text[currentChar.index..$] ];
                    applyModification = true;

                    /* ... and move to the column after the last remaining character before the deleted one, so we can backspace multiple combining characters one by one */
                    m_currentPos.character = (deletedChar.prevChar !is null) ? deletedChar.prevChar.nextColumn.column : deletedChar.column;
                }
                else
                {
                    /* otherwise we ignore the backspace */
                    applyModification = false;
                }
            }
            if(applyModification)
            {
                m_contentMapper.applyModification(mod);
                m_preferredColumn = m_currentPos.character;
            }
        }
    }

    unittest
    {
        /* Test that backspace at the beginning of a normal line, when there is an empty line before it, deletes the first line */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.NORMAL, "\n"),
                        tuple!("type", "text")(LineType.NORMAL, "def\n") ];

        editor.moveTo(Position(1, 0), false);
        editor.backspace();

        assertEqual(cm.mods, [Modification(0, 1, 0, [])]);
        assertEqual(editor.m_currentPos, Position(0, 0));
    }

    unittest
    {
        /* Test that backspace at the beginning of a normal line, when there is a non-empty normal line before it, concatenates both lines */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.NORMAL, "abc\n"),
                        tuple!("type", "text")(LineType.NORMAL, "def\n") ];

        editor.moveTo(Position(1, 0), false);
        editor.backspace();

        assertEqual(cm.mods, [Modification(0, 2, 1, ["abcdef\n"])]);
        assertEqual(editor.m_currentPos, Position(0, 3));
    }

    unittest
    {
        /* Test that backspace at the beginning of a non-normal line, when there is an empty line before it, deletes the first line */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.NORMAL, "\n"),
                        tuple!("type", "text")(LineType.UNRESOLVED_CONFLICT, "def\n")];

        editor.moveTo(Position(1, 0), false);
        editor.backspace();

        assertEqual(cm.mods, [Modification(0, 1, 0, [])]);
        assertEqual(editor.m_currentPos, Position(0, 0));
    }

    unittest
    {
        /* Test that backspace at the beginning of a non-normal line, when there is a non-empty normal line before it, does nothing */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.NORMAL, "abc\n"),
                        tuple!("type", "text")(LineType.UNRESOLVED_CONFLICT, "def\n")];

        editor.moveTo(Position(1, 0), false);
        editor.backspace();

        assertEqual(cm.mods, []);
        assertEqual(editor.m_currentPos, Position(1, 0));
    }

    unittest
    {
        /* Test that backspace at the beginning of a normal line, when there is a non-normal line before it, does nothing */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.UNRESOLVED_CONFLICT, "\n"),
                        tuple!("type", "text")(LineType.NORMAL, "def\n")];

        editor.moveTo(Position(1, 0), false);
        editor.backspace();

        assertEqual(cm.mods, []);
        assertEqual(editor.m_currentPos, Position(1, 0));
    }

    unittest
    {
        /* Test that backspace after a regular char deletes it and moves the cursor */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.NORMAL, "abc\n") ];

        editor.moveTo(Position(0, 3), false);
        editor.backspace();

        assertEqual(cm.mods, [Modification(0, 1, 1, ["ab\n"])]);
        assertEqual(editor.m_currentPos, Position(0, 2));
    }

    unittest
    {
        setlocale(LC_ALL, "");

        /* Test that backspace after a zero-width char does not move the cursor */
        auto cm = new FakeContentMapper();
        auto mcp = new FakeMergeResultContentProvider();
        auto editor = new ContentEditor(mcp, cm);

        mcp.content = [ tuple!("type", "text")(LineType.NORMAL, "abc" ~ two_bytes_zero_columns ~ "\n") ];

        editor.moveTo(Position(0, 3), false);
        editor.backspace();

        assertEqual(cm.mods, [Modification(0, 1, 1, ["abc\n"])]);
        assertEqual(editor.m_currentPos, Position(0, 3));
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
            if(originalLine.type != LineType.NORMAL)
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
                    if(nextLine.type != LineType.NORMAL)
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
    bool enter()
    {
        bool textInserted = false;

        auto line = m_mcp.getLineWithType(m_currentPos.line);
        if(line.type == LineType.NORMAL || line.type == LineType.NO_SOURCE_LINE)
        {
            auto currentChar = line.text.toStringColumns(m_currentPos.character).currentChar;

            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 2;
            mod.lines = [ line.text[0..currentChar.index] ~ "\n", line.text[currentChar.index..$] ];
            m_contentMapper.applyModification(mod);

            m_currentPos.line++;
            m_preferredColumn = m_currentPos.character = 0;

            textInserted = true;
        }
        return textInserted;
    }
    bool insertText(string text)
    {
        bool textInserted = false;

        auto line = m_mcp.getLineWithType(m_currentPos.line);
        if(line.type == LineType.NORMAL || line.type == LineType.NO_SOURCE_LINE)
        {
            auto currentChar = line.text.toStringColumns(m_currentPos.character).currentChar;

            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 1;
            mod.lines = [ line.text[0..currentChar.index] ~ text ~ line.text[currentChar.index..$] ];
            m_contentMapper.applyModification(mod);

            /* Read back the modified line */
            line = m_mcp.getLineWithType(m_currentPos.line);

            auto nextChar = line.text.toStringColumns(m_currentPos.character).currentChar.nextChar;
            m_preferredColumn = m_currentPos.character = nextChar.column;

            textInserted = true;
        }
        return textInserted;
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

version(unittest)
{
    class FakeContentMapper: ContentMapper
    {
        Modification[] mods;

        override void applyModification(Modification mod)
        {
            mods ~= mod;
        }
    }

    class FakeMergeResultContentProvider: MergeResultContentProvider
    {
        Tuple!(LineType, "type", string, "text")[] content;

        this()
        {
            super(null, null, null, null, null);
        }

        override Tuple!(LineType, "type", string, "text") getLineWithType(int lineNumber)
        {
            if(lineNumber < content.length)
            {
                return content[lineNumber];
            }
            else
            {
                return tuple!("type", "text")(LineType.NONE, "\n");
            }
        }

        override int getContentHeight()
        {
            return to!int(content.length);
        }
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
