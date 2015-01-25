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

import deimos.ncurses.curses;

import modifiedcontentprovider;
import contenteditor;
import contentpane;


class EditableContentPane: ContentPane
{
private:
    ContentEditor m_editor;

    int m_cursor_x;
    int m_cursor_y;

public:
    this(int x, int y,
         int width, int height,
         ModifiedContentProvider mcp,
         ContentEditor editor)
    {
        super(x, y, width, height, 100, 100, mcp);
        m_editor = editor;
    }

    bool handleKeyboardInput(int ch)
    {
        bool handled = true;

        switch(ch)
        {
        case KEY_LEFT:
            m_cursor_x--;
            m_editor.moveTo(Position(m_cursor_y, m_cursor_x), false);
            break;
        case KEY_RIGHT:
            m_cursor_x++;
            m_editor.moveTo(Position(m_cursor_y, m_cursor_x), false);
            break;
        case KEY_UP:
            m_cursor_y--;
            m_editor.moveTo(Position(m_cursor_y, m_cursor_x), false);

            auto distanceOffScreen = m_scrollPositionY - m_cursor_y;
            if(distanceOffScreen > 0)
            {
                scrollY(-distanceOffScreen);
            }
            break;
        case KEY_DOWN:
            m_cursor_y++;
            m_editor.moveTo(Position(m_cursor_y, m_cursor_x), false);

            auto distanceOffScreen = m_cursor_y - m_height - m_scrollPositionY + 1;
            if(distanceOffScreen > 0)
            {
                scrollY(distanceOffScreen);
            }
            break;
        case KEY_DC:
            m_editor.delete_();
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

