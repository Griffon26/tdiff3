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
module ui;

import deimos.ncurses.curses;
import std.algorithm;

import colors;
import contenteditor;
import editablecontentpane;
import icontentprovider;
import iformattedcontentprovider;
import inputpanes;
import modifiedcontentprovider;

class Ui
{
private:
    InputPanes m_inputPanes;
    EditableContentPane m_editableContentPane;

public:
    this(IFormattedContentProvider[3] cps, IContentProvider[3] lnps, ModifiedContentProvider modifiedContentProvider)
    {
        initscr();
        cbreak();
        noecho();
        keypad(stdscr, true);

        if(!has_colors())
        {
            endwin();
            throw new Exception("Your terminal does not support color\n");
        }

        start_color();
        init_color(Color.BLACK, 0, 0, 0);
        init_color(Color.RED, 1000, 0, 0);
        init_color(Color.BLUE, 0, 0, 800);
        init_color(Color.PURPLE, 600, 0, 600);
        init_color(Color.GREEN, 0, 600, 0);
        init_color(Color.WHITE, 1000, 1000, 1000);
        init_color(Color.GRAY, 900, 900, 900);

        //init_pair(ColorPair.NORMAL, Color.BLACK, Color.WHITE);
        assume_default_colors(Color.BLACK, Color.WHITE);
        init_pair(ColorPair.A_B_SAME, Color.PURPLE, Color.GRAY);
        init_pair(ColorPair.A_C_SAME, Color.GREEN, Color.GRAY);
        init_pair(ColorPair.B_C_SAME, Color.BLUE, Color.GRAY);
        init_pair(ColorPair.DIFFERENT, Color.RED, Color.GRAY);
        bkgd(COLOR_PAIR(ColorPair.NORMAL));

        m_inputPanes = new InputPanes(cps, lnps);

        auto contentEditor = new ContentEditor(modifiedContentProvider);
        m_editableContentPane = new EditableContentPane(modifiedContentProvider, contentEditor);
    }

    void setPosition(int x, int y, int screenWidth, int screenHeight)
    {
        int inputX = x;
        int inputY = y;
        int inputWidth = screenWidth;
        int inputHeight = screenHeight / 2;

        m_inputPanes.setPosition(inputX, inputY, inputWidth, inputHeight);

        int outputX = inputX;
        int outputY = inputY + inputHeight;
        int outputWidth = inputWidth;
        int outputHeight = screenHeight - inputHeight;

        m_editableContentPane.setPosition(outputX, outputY, outputWidth, outputHeight);
    }

    void handleResize()
    {
        int max_x, max_y;
        getmaxyx(stdscr, max_y, max_x);

        clear();

        int width = max(max_x + 1, 30);
        int height = max(max_y + 1, 10);

        setPosition(0, 0, width, height);
        refresh();
    }

    void mainLoop()
    {
        /* Refresh stdscr to make sure the static items are drawn and stdscr won't
         * be refreshed again when getch() is called */
        refresh();
        m_inputPanes.redraw();
        m_editableContentPane.redraw();

        int ch = 'x';
        while(ch != 'q')
        {
            ch = getch();

            if(!m_editableContentPane.handleKeyboardInput(ch))
            {
                switch(ch)
                {
                case 'j':
                    m_inputPanes.scrollY(1);
                    break;
                case 'i':
                    m_inputPanes.scrollY(-1);
                    break;
                case 'k':
                    m_inputPanes.scrollX(-1);
                    break;
                case 'l':
                    m_inputPanes.scrollX(1);
                    break;
                case KEY_RESIZE:
                    handleResize();
                    break;
                default:
                    break;
                }
            }

            m_inputPanes.redraw();
            m_editableContentPane.redraw();
        }

        endwin();
    }
}
