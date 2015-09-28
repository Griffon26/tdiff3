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
import highlightaddingcontentprovider;
import myassert;


/**
 * The ContentEditor is responsible for translating editing commands received
 * from the Ui into modifications and send them to the ContentMapper.  It is
 * also responsible for maintaining the cursor position and selection state,
 * including the currently selected merge result section. It tells the
 * HighlightAddingContentProviders which lines to highlight based on the
 * selection.
 *
 * <object data="../uml/contenteditor.svg" type="image/svg+xml"></object>
 */
/*
 * @startuml
 * hide circle
 * skinparam minClassWidth 70
 * skinparam classArrowFontSize 8
 * class Ui --> ContentEditor: sends editing commands\ngets focus/cursor position
 * ContentEditor --> ContentMapper: applies modifications\nrequests section location\ngets line source
 * ContentEditor --> "1" HighlightAddingContentProvider: sets output lines to be highlighted
 * ContentEditor --> "3" HighlightAddingContentProvider: sets input lines to be highlighted
 * ContentEditor --> ILineProvider: gets line
 *
 * url of Ui is [[../ui/Ui.html]]
 * url of HighlightAddingContentProvider is [[../highlightaddingcontentprovider/HighlightAddingContentProvider.html]]
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
    int m_selectedSection;

    string m_copyPasteBuffer;
    HighlightAddingContentProvider[3] m_d3cps;
    HighlightAddingContentProvider m_mcp;
    ContentMapper m_contentMapper;

    bool m_inputFocusChanged;
    bool m_outputFocusChanged;
    Position m_inputFocusPosition;
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

    this(HighlightAddingContentProvider[3] diff3ContentProviders, HighlightAddingContentProvider mergeResultContentProvider, ContentMapper contentMapper)
    {
        m_d3cps = diff3ContentProviders;
        m_mcp = mergeResultContentProvider;
        m_contentMapper = contentMapper;
    }

    private void setSelectedSection(int sectionIndex)
    {
        m_selectedSection = sectionIndex;

        auto sectionInfo = m_contentMapper.getSectionInfo(sectionIndex);
        foreach(cp; m_d3cps)
        {
            cp.setHighlight(sectionInfo.inputPaneLineNumbers);
        }
        m_mcp.setHighlight(sectionInfo.mergeResultPaneLineNumbers);
        updateInputFocusPosition(Position(sectionInfo.inputPaneLineNumbers.firstLine, 0));
        updateOutputFocusPosition(Position(sectionInfo.mergeResultPaneLineNumbers.firstLine, 0));
    }

    /* Editor operations */
    void selectNextConflict()
    {
        int nextConflict = m_contentMapper.findNextConflictingSection(m_selectedSection);
        if(nextConflict != -1)
        {
            setSelectedSection(nextConflict);
        }
    }

    void selectPreviousConflict()
    {
        int previousConflict = m_contentMapper.findPreviousConflictingSection(m_selectedSection);
        if(previousConflict != -1)
        {
            setSelectedSection(previousConflict);
        }
    }

    void selectNextUnsolvedConflict()
    {
        int nextConflict = m_contentMapper.findNextUnsolvedConflictingSection(m_selectedSection);
        if(nextConflict != -1)
        {
            setSelectedSection(nextConflict);
        }
    }

    void selectPreviousUnsolvedConflict()
    {
        int previousConflict = m_contentMapper.findPreviousUnsolvedConflictingSection(m_selectedSection);
        if(previousConflict != -1)
        {
            setSelectedSection(previousConflict);
        }
    }

    void toggleCurrentSectionSource(LineSource lineSource)
    {
        m_contentMapper.toggleSectionSource(m_selectedSection, lineSource);
        setSelectedSection(m_selectedSection);
    }

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
            if(m_currentPos.character < m_mcp.get(m_currentPos.line).lengthInColumns(true) - 1)
            {
                newPos.character++;
            }
            break;
        case Movement.LEFT:
            if(m_currentPos.character > 0)
            {
                newPos.character--;
            }
            break;
        case Movement.UP:
            if(m_currentPos.line > 0)
            {
                newPos.line--;
                newPos.character = min(newPos.character, m_mcp.get(newPos.line).lengthInColumns(true) - 1);
            }
            break;
        case Movement.DOWN:
            if(m_currentPos.line < m_mcp.getContentHeight() - 1)
            {
                newPos.line++;
                newPos.character = min(newPos.character, m_mcp.get(newPos.line).lengthInColumns(true) - 1);
            }
            break;
        case Movement.LINEHOME:
            newPos.character = 0;
            break;
        case Movement.LINEEND:
            newPos.character = m_mcp.get(m_currentPos.line).lengthInColumns(true) - 1;
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
    private void updateInputFocusPosition(Position pos)
    {
        m_inputFocusChanged = true;
        m_inputFocusPosition = pos;
    }

    private void updateOutputFocusPosition(Position pos)
    {
        m_outputFocusChanged = true;
        m_outputFocusPosition = pos;
    }

    bool inputFocusNeedsUpdate()
    {
        return m_inputFocusChanged;
    }

    bool outputFocusNeedsUpdate()
    {
        return m_outputFocusChanged;
    }

    Position getInputFocusPosition()
    {
        m_inputFocusChanged = false;
        return m_inputFocusPosition;
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
                modifiedLineAtBeginning = m_mcp.get(firstPos.line).substringColumns(0, firstPos.character, true);
            }

            /* If the selection ends at the last position of a line, nothing remains to be added to the edited line */
            auto lastLineColumns = m_mcp.get(lastPos.line).lengthInColumns(true);
            if(lastPos.character != lastLineColumns - 1)
            {
                modifiedLineAtEnd = m_mcp.get(lastPos.line).substringColumns(lastPos.character + 1, lastLineColumns, true);
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
            auto mod = Modification();
            mod.firstLine = m_currentPos.line;
            mod.originalLineCount = 1;
            mod.editedLineCount = 1;

            auto originalLine = m_mcp.get(m_currentPos.line);
            auto originalLineColumns = originalLine.lengthInColumns(true);

            if(m_currentPos.character == originalLineColumns - 1)
            {
                mod.lines = [ originalLine.substringColumns(0, m_currentPos.character, true) ~ m_mcp.get(m_currentPos.line + 1) ];
                mod.originalLineCount = 2;
            }
            else
            {
                mod.lines = [ originalLine.substringColumns(0, m_currentPos.character, true) ~ originalLine.substringColumns(m_currentPos.character + 1, originalLineColumns, true) ];
            }
            m_contentMapper.applyModification(mod);
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
