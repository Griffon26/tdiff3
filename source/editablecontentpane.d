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
module editablecontentpane;

import deimos.ncurses.curses;

import modifiedcontentprovider;
import contenteditor;
import contentpane;


/**
  * EditableContentPane handles keyboard input from ncurses and translates it
  * into editing commands that it passes on to ContentEditor.
  *
  * <img src="http://yuml.me/diagram/scruffy/class/
  *           [ContentPane]^-[EditableContentPane {bg:limegreen}],
  *           [ContentPane]-gets content&gt;[IContentProvider],
  *           [app]-sends keystrokes&gt;[EditableContentPane {bg:limegreen}],
  *           [EditableContentPane {bg:limegreen}]-sends editing commands&gt;[ContentEditor],
  *           [ContentEditor]-applies modifications&gt;[ModifiedContentProvider],
  *           [IContentProvider]^-.-[ModifiedContentProvider]
  *          "/>
  */
class EditableContentPane: ContentPane
{
private:
    ContentEditor m_editor;

public:
    this(int x, int y,
         int width, int height,
         ModifiedContentProvider mcp,
         ContentEditor editor)
    {
        super(x, y, width, height, 0, 0, mcp);
        updateScrollLimits();
        m_editor = editor;
    }

    bool handleKeyboardInput(int ch)
    {
        bool handled = true;

        switch(ch)
        {
        case KEY_LEFT:
            m_editor.move(ContentEditor.Movement.LEFT, false);
            break;
        case KEY_RIGHT:
            m_editor.move(ContentEditor.Movement.RIGHT, false);
            break;
        case KEY_UP:
            m_editor.move(ContentEditor.Movement.UP, false);
            break;
        case KEY_DOWN:
            m_editor.move(ContentEditor.Movement.DOWN, false);
            break;
        case KEY_HOME:
            m_editor.move(ContentEditor.Movement.LINEHOME, false);
            break;
        case KEY_END:
            m_editor.move(ContentEditor.Movement.LINEEND, false);
            break;
        case KEY_DC:
            m_editor.delete_();
            updateScrollLimits();
            drawMissingLines(m_scrollPositionY, 0, m_height);
            break;
        case KEY_PPAGE:
            resize(m_width, m_height - 10);
            break;
        case KEY_NPAGE:
            resize(m_width, m_height + 10);
            break;
        default:
            handled = false;
            break;
        }


        int relativeCursorPositionX = m_editor.getCursorPosition().character - m_scrollPositionX;
        if(relativeCursorPositionX < 0)
        {
            scrollX(relativeCursorPositionX);
        }
        else if(relativeCursorPositionX > (m_width - 1))
        {
            scrollX(relativeCursorPositionX - (m_width - 1));
        }

        int relativeCursorPositionY = m_editor.getCursorPosition().line - m_scrollPositionY;
        if(relativeCursorPositionY < 0)
        {
            scrollY(relativeCursorPositionY);
        }
        else if(relativeCursorPositionY > (m_height - 1))
        {
            scrollY(relativeCursorPositionY - (m_height - 1));
        }

        return handled;
    }



    /* Redraws content */
    override void redraw()
    {
        auto pos = m_editor.getCursorPosition();
        wmove(m_pad, pos.line - m_scrollPositionY, pos.character);
        super.redraw();
    }
}

