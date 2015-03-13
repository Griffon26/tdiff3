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
import std.conv;

import colors;
import common;
import contenteditor;
import editablecontentpane;
import icontentprovider;
import iformattedcontentprovider;
import inputpanes;
import modifiedcontentprovider;
import theme;

class Ui
{
private:
    InputPanes m_inputPanes;
    EditableContentPane m_editableContentPane;
    Theme m_theme;

public:
    this(IFormattedContentProvider[3] cps, IContentProvider[3] lnps, ModifiedContentProvider modifiedContentProvider)
    {
        m_theme = new Theme();

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

        short colorcube(short colorcubesize, short r, short g, short b)
        {
            short colorcubeoffset = 16;
            return to!short(colorcubeoffset + r * colorcubesize * colorcubesize + g * colorcubesize + b);
        }

        short grayscale(short colorcubesize, short gray)
        {
            auto grayscalerampoffset = 16 + colorcubesize * colorcubesize * colorcubesize;
            return to!short(grayscalerampoffset + gray);
        }


        // KDiff3's colors in RGB:
        //   black     0,   0,   0
        //   red     255,   0,   0
        //   blue      0,   0, 200
        //   purple  150,   0, 150
        //   green     0, 150,   0
        //   white   255, 255, 255
        //   gray    224, 224, 224

        short colorcubesize;
        short black, red, blue, purple, green, white, gray;

        switch(COLORS)
        {
        case 256:
            // Closest approximation of KDiff3's colors using XTerm's 256-color palette
            colorcubesize = 6;
            black = colorcube(colorcubesize, 0,0,0);
            red = colorcube(colorcubesize, 5,0,0);
            blue = colorcube(colorcubesize, 0,0,4);
            purple = colorcube(colorcubesize, 2,0,2);
            green = colorcube(colorcubesize, 0,2,0);
            white = colorcube(colorcubesize, 5,5,5);
            gray = grayscale(colorcubesize, 21);
            break;
        case 88:
            // Closest approximation of KDiff3's colors using XTerm's 88-color palette
            colorcubesize = 4;
            black = colorcube(colorcubesize, 0,0,0);
            red = colorcube(colorcubesize, 3,0,0);
            blue = colorcube(colorcubesize, 0,0,2);
            purple = colorcube(colorcubesize, 1,0,1);
            green = colorcube(colorcubesize, 0,1,0);
            white = colorcube(colorcubesize, 3,3,3);
            gray = grayscale(colorcubesize, 7);
            break;
        default:
            colorcubesize = 0;
            break;
        }

        if(colorcubesize > 0)
        {
            assume_default_colors(black, white);

            init_pair(ColorPair.DIFFERENT, red,    gray);
            init_pair(ColorPair.A_B_SAME,  purple, gray);
            init_pair(ColorPair.A_C_SAME,  green,  gray);
            init_pair(ColorPair.B_C_SAME,  blue,   gray);
            init_pair(ColorPair.NORMAL,    black,  white);

            m_theme.setDiffStyleAttributes(DiffStyle.DIFFERENT, false, COLOR_PAIR(ColorPair.DIFFERENT));
            m_theme.setDiffStyleAttributes(DiffStyle.A_B_SAME, false, COLOR_PAIR(ColorPair.A_B_SAME));
            m_theme.setDiffStyleAttributes(DiffStyle.A_C_SAME, false, COLOR_PAIR(ColorPair.A_C_SAME));
            m_theme.setDiffStyleAttributes(DiffStyle.B_C_SAME, false, COLOR_PAIR(ColorPair.B_C_SAME));
            m_theme.setDiffStyleAttributes(DiffStyle.ALL_SAME, false, COLOR_PAIR(ColorPair.NORMAL));
        }
        else
        {
            assume_default_colors(Color.WHITE, Color.BLACK);

            init_pair(ColorPair.DIFFERENT, Color.RED, Color.BLACK);
            init_pair(ColorPair.A_B_SAME, Color.PURPLE, Color.BLACK);
            init_pair(ColorPair.A_C_SAME, Color.GREEN, Color.BLACK);
            init_pair(ColorPair.B_C_SAME, Color.BLUE, Color.BLACK);
            init_pair(ColorPair.NORMAL, Color.WHITE, Color.BLACK);

            m_theme.setDiffStyleAttributes(DiffStyle.DIFFERENT, false, COLOR_PAIR(ColorPair.DIFFERENT) );
            m_theme.setDiffStyleAttributes(DiffStyle.A_B_SAME, false, COLOR_PAIR(ColorPair.A_B_SAME) );
            m_theme.setDiffStyleAttributes(DiffStyle.A_C_SAME, false, COLOR_PAIR(ColorPair.A_C_SAME) );
            m_theme.setDiffStyleAttributes(DiffStyle.B_C_SAME, false, COLOR_PAIR(ColorPair.B_C_SAME) | A_BOLD);
            m_theme.setDiffStyleAttributes(DiffStyle.ALL_SAME, false, COLOR_PAIR(ColorPair.NORMAL));
        }

        bkgd(COLOR_PAIR(ColorPair.NORMAL));

        m_inputPanes = new InputPanes(cps, lnps, m_theme);

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
