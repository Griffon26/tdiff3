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
module formattedcontentpane;

import deimos.ncurses.curses;
import std.string;

import colors;
import common;
import contentpane;
import iformattedcontentprovider;
import theme;

/**
 * FormattedContentPane is a ContentPane that shows content of an IFormattedContentProvider
 */
class FormattedContentPane: ContentPane
{
    private IFormattedContentProvider m_fcp;
    private Theme m_theme;

    this(IFormattedContentProvider fcp, Theme theme)
    {
        m_fcp = fcp;
        m_theme = theme;
        super(fcp);
    }

    override protected void drawMissingLine(int contentLine)
    {
        auto line = m_fcp.get(contentLine);
        auto styleList = m_fcp.getFormat(contentLine);
        if(line.isNull)
        {
            line = "\n";
        }

        int offset = 0;
        auto defaultAttributes = m_theme.getDiffStyleAttributes(DiffStyle.ALL_SAME, false);

        if(styleList.empty)
        {
            wattrset(m_pad, defaultAttributes);
            wprintw(m_pad, toStringz(line));
        }
        else
        {
            foreach(styleFragment; styleList)
            {
                auto attributes = m_theme.getDiffStyleAttributes(styleFragment.style, false);
                wattrset(m_pad, attributes);
                wprintw(m_pad, toStringz(line[offset..offset + styleFragment.length]));
                offset += styleFragment.length;
            }
        }
    }
}

