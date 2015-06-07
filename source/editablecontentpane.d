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

import common;
import contenteditor;
import formattedcontentpane;
import highlightaddingcontentprovider;
import theme;


/**
 * EditableContentPane is a FormattedContentPane that in addition to its
 * content also draws a text cursor at a position previously set by the Ui.
 *
 * <object data="../uml/editablecontentpane.svg" type="image/svg+xml"></object>
 */
/*
 * @startuml
 * hide circle
 * skinparam minClassWidth 70
 * skinparam classArrowFontSize 8
 * Ui --> EditableContentPane: sets cursor/focus position
 * FormattedContentPane <|-- EditableContentPane
 * FormattedContentPane --> "gets content" IFormattedContentProvider
 *
 * url of Ui is [[../ui/Ui.html]]
 * url of FormattedContentPane is [[../formattedcontentpane/FormattedContentPane.html]]
 * url of IFormattedContentProvider is [[../iformattedcontentprovider/IFormattedContentProvider.html]]
 * @enduml
 *
 */
class EditableContentPane: FormattedContentPane
{
private:
    Position m_cursorPos;

public:
    this(HighlightAddingContentProvider mergeResultContentProvider,
         Theme theme)
    {
        super(mergeResultContentProvider, theme);
        updateScrollLimits();
    }

    void setCursorPosition(Position pos)
    {
        m_cursorPos = pos;
    }

    /* Redraws content */
    override void redraw()
    {
        wmove(m_pad, m_cursorPos.line - m_scrollPositionY, m_cursorPos.character);
        super.redraw();
    }
}

