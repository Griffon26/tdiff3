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
module inputpanes;

import std.conv;
import std.math;

import deimos.ncurses.curses;

import contentpane;
import formattedcontentpane;
import icontentprovider;
import iformattedcontentprovider;

/**
 * InputPanes manages the FormattedContentPanes for the three input files and
 * synchronizes scrolling between them. It also draws borders and line numbers.
 */
class InputPanes
{
private:
    ContentPane[3] m_lineNumberPanes;
    FormattedContentPane[3] m_inputPanes;

    int m_lineNumberWidth;

    int scrollBarWidth = 1;
    int borderWidth = 1;
    int diffStatusWidth = 1;
    int nrOfPanes = 3;

public:
    this(IFormattedContentProvider[3] cps, IContentProvider[3] lnps)
    {
        assert(cps[0].getContentHeight() == cps[1].getContentHeight() &&
               cps[0].getContentHeight() == cps[2].getContentHeight());
        assert(lnps[0].getContentHeight() == lnps[1].getContentHeight() &&
               lnps[0].getContentHeight() == lnps[2].getContentHeight());
        assert(cps[0].getContentHeight() == lnps[0].getContentHeight());

        assert(lnps[0].getContentWidth() == lnps[1].getContentWidth() &&
               lnps[0].getContentWidth() == lnps[2].getContentWidth());

        m_lineNumberWidth = lnps[0].getContentWidth();

        for(int i = 0; i < nrOfPanes; i++)
        {
            m_lineNumberPanes[i] = new ContentPane(lnps[i]);
            m_inputPanes[i] = new FormattedContentPane(cps[i]);
        }
    }

    void setPosition(int x, int y, int width, int height)
    {
        /* Draw a box around the input panes */
        mvhline(y, x, ACS_HLINE, width - 1);
        mvvline(y, x, ACS_VLINE, height - 1);
        mvhline(y + height - 1, x, ACS_HLINE, width - 1);
        mvvline(y, x + width - 1, ACS_VLINE, height - 1);

        mvaddch(y, x, ACS_ULCORNER);
        mvaddch(y, x + width - 1, ACS_URCORNER);
        mvaddch(y + height - 1, x, ACS_LLCORNER);
        mvaddch(y + height - 1, x + width - 1, ACS_LRCORNER);

        int summedPaneWidth = width - scrollBarWidth -
                              nrOfPanes * (borderWidth + m_lineNumberWidth + diffStatusWidth) -
                              borderWidth;
        int inputPaneHeight = height - 2 * borderWidth;

        int remainingPaneWidth = summedPaneWidth;
        int paneOffset = x;
        for(int i = 0; i < nrOfPanes; i++)
        {
            int paneWidth = remainingPaneWidth / (nrOfPanes - i);

            /* Draw borders before the second and third pane */
            if(i != 0)
            {
                mvaddch(y, paneOffset, ACS_TTEE);
                mvaddch(y + height - 1, paneOffset, ACS_BTEE);
                mvvline(y + 1, paneOffset, ACS_VLINE, height - 2);
            }
            paneOffset += borderWidth;

            /* Draw line numbers */
            m_lineNumberPanes[i].setPosition(paneOffset, y + 1, m_lineNumberWidth, inputPaneHeight);
            paneOffset += m_lineNumberWidth + diffStatusWidth;

            /* Draw file content */
            m_inputPanes[i].setPosition(paneOffset, y + 1, paneWidth, inputPaneHeight);
            paneOffset += paneWidth;

            remainingPaneWidth -= paneWidth;
        }
    }

    void scrollX(int n)
    {
        foreach(ip; m_inputPanes)
        {
            ip.scrollX(n);
        }
    }

    void scrollY(int n)
    {
        foreach(lnp; m_lineNumberPanes)
        {
            lnp.scrollY(n);
        }
        foreach(ip; m_inputPanes)
        {
            ip.scrollY(n);
        }
    }

    /* Redraws content */
    void redraw()
    {
        foreach(lnp; m_lineNumberPanes)
        {
            lnp.redraw();
        }
        foreach(ip; m_inputPanes)
        {
            ip.redraw();
        }
    }

}

