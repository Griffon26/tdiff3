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

/**
 * FormattedContentPane is a ContentPane that shows content of an IFormattedContentProvider
 */
class FormattedContentPane: ContentPane
{
    private IFormattedContentProvider m_fcp;

    this(IFormattedContentProvider fcp)
    {
        m_fcp = fcp;
        super(fcp);
    }

    private ColorPair diffStyleToColor(DiffStyle d)
    {
        switch(d)
        {
        case DiffStyle.ALL_SAME:
            return ColorPair.NORMAL;
        case DiffStyle.A_B_SAME:
            return ColorPair.A_B_SAME;
        case DiffStyle.A_C_SAME:
            return ColorPair.A_C_SAME;
        case DiffStyle.B_C_SAME:
            return ColorPair.B_C_SAME;
        case DiffStyle.DIFFERENT:
            return ColorPair.DIFFERENT;
        default:
            assert(false);
        }
    }

    override protected void drawMissingLine(int contentLine)
    {
        auto line = m_fcp.get(contentLine);
        auto lineFormat = m_fcp.getFormat(contentLine);
        if(line.isNull)
        {
            line = "\n";
        }

        int offset = 0;
        int equal = true;
        ColorPair sameColor = diffStyleToColor(DiffStyle.ALL_SAME);
        ColorPair differentColor = diffStyleToColor(lineFormat.style);

        if(lineFormat.runs.empty)
        {
            wattron(m_pad, COLOR_PAIR(sameColor));
            wprintw(m_pad, toStringz(line));
            wattroff(m_pad, COLOR_PAIR(sameColor));
        }
        else
        {
            foreach(run; lineFormat.runs)
            {
                wattron(m_pad, COLOR_PAIR(equal ? sameColor : differentColor));
                wprintw(m_pad, toStringz(line[offset..offset + run]));
                wattroff(m_pad, COLOR_PAIR(equal ? sameColor : differentColor));
                offset += run;
                equal = !equal;
            }
        }
    }
}

