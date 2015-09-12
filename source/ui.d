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

import core.stdc.config;
import core.stdc.errno;
import core.sys.posix.sys.ioctl;
import core.sys.posix.signal;
import core.sys.posix.termios;
import core.sys.posix.unistd;
import deimos.ncurses.curses;
import std.algorithm;
import std.conv;
import std.string;

import termkey;

import colors;
import common;
import contenteditor;
import contentmapper;
import editablecontentpane;
import highlightaddingcontentprovider;
import icontentprovider;
import iformattedcontentprovider;
import inputpanes;
import mergeresultcontentprovider;
import theme;

enum SIGWINCH = 28;

extern (C) void sigwinch_handler(int signum)
{
    winsize ws;
    if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == -1)
    {
        log("sigwinch_handler: failed to retrieve new window size");
    }
    else
    {
        // TODO: check if calling resizeterm eventually blocks because it queues a KEY_RESIZE
        resizeterm(ws.ws_row, ws.ws_col);
    }
}

/**
 * The UI is responsible for handling keyboard input and controlling the other
 * UI-related classes, such as ContentPanes, the ContentEditor and the Theme.
 *
 * <object data="../uml/ui.svg" type="image/svg+xml"></object>
 */
/*
 * @startuml
 * hide circle
 * skinparam minClassWidth 70
 * skinparam classArrowFontSize 8
 * class Ui
 * Ui --> ContentEditor: sends editing commands\ngets focus/cursor position
 * Ui --> InputPanes: sets focus position
 * Ui --> EditableContentPane: sets focus/cursor position
 *
 * url of InputPanes is [[../inputpanes/InputPanes.html]]
 * url of ContentEditor is [[../contenteditor/ContentEditor.html]]
 * url of EditableContentPane is [[../editablecontentpane/EditableContentPane.html]]
 * @enduml
 */
class Ui
{
private:
    MergeResultContentProvider m_mergeResultContentProvider;
    InputPanes m_inputPanes;
    EditableContentPane m_editableContentPane;
    ContentEditor m_editor;
    Theme m_theme;
    termios m_originalTermios;

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

    void set_light_theme(Theme theme)
    {
        short colorcubesize;
        short black, red, blue, purple, green, white, gray;

        // KDiff3's default colors in RGB:
        //   black     0,   0,   0
        //   red     255,   0,   0
        //   blue      0,   0, 200
        //   purple  150,   0, 150
        //   green     0, 150,   0
        //   white   255, 255, 255
        //   gray    224, 224, 224

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
            assert(false);
        }

        assume_default_colors(black, white);

        init_pair(ColorPair.DIFFERENT, red,    gray);
        init_pair(ColorPair.A_B_SAME,  purple, gray);
        init_pair(ColorPair.A_C_SAME,  green,  gray);
        init_pair(ColorPair.B_C_SAME,  blue,   gray);
        init_pair(ColorPair.NORMAL,    black,  white);
        init_pair(ColorPair.NORMAL_HIGHLIGHTED,
                                       black,  gray);

        theme.setDiffStyleAttributes(DiffStyle.DIFFERENT, false, COLOR_PAIR(ColorPair.DIFFERENT));
        theme.setDiffStyleAttributes(DiffStyle.A_B_SAME, false, COLOR_PAIR(ColorPair.A_B_SAME));
        theme.setDiffStyleAttributes(DiffStyle.A_C_SAME, false, COLOR_PAIR(ColorPair.A_C_SAME));
        theme.setDiffStyleAttributes(DiffStyle.B_C_SAME, false, COLOR_PAIR(ColorPair.B_C_SAME));
        theme.setDiffStyleAttributes(DiffStyle.ALL_SAME, false, COLOR_PAIR(ColorPair.NORMAL));
        theme.setDiffStyleAttributes(DiffStyle.ALL_SAME_HIGHLIGHTED, false, COLOR_PAIR(ColorPair.NORMAL_HIGHLIGHTED));
    }

    void set_dark_theme(Theme theme)
    {
        short colorcubesize;
        short black, red, blue, purple, green, darkgray, gray;

        // KDiff3's default colors in RGB:
        //   black     0,   0,   0
        //   red     255,   0,   0
        //   blue      0,   0, 200
        //   purple  150,   0, 150
        //   green     0, 150,   0
        //   white   255, 255, 255
        //   gray    224, 224, 224

        switch(COLORS)
        {
        case 256:
            colorcubesize = 6;
            black = colorcube(colorcubesize, 0,0,0);
            red = colorcube(colorcubesize, 4,0,0);
            blue = colorcube(colorcubesize, 0,2,5);
            purple = colorcube(colorcubesize, 4,0,4);
            green = colorcube(colorcubesize, 0,4,0);
            darkgray = grayscale(colorcubesize, 4); // 8
            gray = grayscale(colorcubesize, 21);
            break;
        case 88:
            colorcubesize = 4;
            black = colorcube(colorcubesize, 0,0,0);
            red = colorcube(colorcubesize, 2,0,0);
            blue = colorcube(colorcubesize, 0,1,3);
            purple = colorcube(colorcubesize, 2,0,2);
            green = colorcube(colorcubesize, 0,2,0);
            darkgray = grayscale(colorcubesize, 0); // 1
            gray = grayscale(colorcubesize, 7);
            break;
        default:
            assert(false);
        }

        assume_default_colors(gray, black);

        init_pair(ColorPair.DIFFERENT, red,    darkgray);
        init_pair(ColorPair.A_B_SAME,  purple, darkgray);
        init_pair(ColorPair.A_C_SAME,  green,  darkgray);
        init_pair(ColorPair.B_C_SAME,  blue,   darkgray);
        init_pair(ColorPair.NORMAL,    gray,   black);
        init_pair(ColorPair.NORMAL_HIGHLIGHTED,
                                       gray,   darkgray);

        theme.setDiffStyleAttributes(DiffStyle.DIFFERENT, false, COLOR_PAIR(ColorPair.DIFFERENT));
        theme.setDiffStyleAttributes(DiffStyle.A_B_SAME, false, COLOR_PAIR(ColorPair.A_B_SAME));
        theme.setDiffStyleAttributes(DiffStyle.A_C_SAME, false, COLOR_PAIR(ColorPair.A_C_SAME));
        theme.setDiffStyleAttributes(DiffStyle.B_C_SAME, false, COLOR_PAIR(ColorPair.B_C_SAME));
        theme.setDiffStyleAttributes(DiffStyle.ALL_SAME, false, COLOR_PAIR(ColorPair.NORMAL));
        theme.setDiffStyleAttributes(DiffStyle.ALL_SAME_HIGHLIGHTED, false, COLOR_PAIR(ColorPair.NORMAL_HIGHLIGHTED));
    }

public:
    this(IFormattedContentProvider[3] cps, IContentProvider[3] lnps, MergeResultContentProvider mergeResultContentProvider, ContentMapper contentMapper)
    {
        m_mergeResultContentProvider = mergeResultContentProvider;

        m_theme = new Theme();

        /* Save current terminal settings */
        tcgetattr(0, &m_originalTermios);

        initscr();
        cbreak();
        noecho();
        keypad(stdscr, true);

        sigaction_t oldsa;
        sigaction_t sa;
        sa.sa_handler = &sigwinch_handler;

        sigaction (SIGWINCH, &sa, null);

        if(!has_colors())
        {
            endwin();
            throw new Exception("Your terminal does not support color\n");
        }

        start_color();

        if(COLORS == 88 || COLORS == 256)
        {
            set_dark_theme(m_theme);
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
            m_theme.setDiffStyleAttributes(DiffStyle.ALL_SAME_HIGHLIGHTED, false, COLOR_PAIR(ColorPair.NORMAL));
        }

        bkgd(COLOR_PAIR(ColorPair.NORMAL));

        HighlightAddingContentProvider[3] hcps;
        hcps[0] = new HighlightAddingContentProvider(cps[0]);
        hcps[1] = new HighlightAddingContentProvider(cps[1]);
        hcps[2] = new HighlightAddingContentProvider(cps[2]);

        cps[0] = hcps[0];
        cps[1] = hcps[1];
        cps[2] = hcps[2];

        auto highlightedMergeResultContentProvider = new HighlightAddingContentProvider(mergeResultContentProvider);

        m_inputPanes = new InputPanes(cps, lnps, m_theme);
        m_editableContentPane = new EditableContentPane(highlightedMergeResultContentProvider, m_theme);

        m_editor = new ContentEditor(hcps, highlightedMergeResultContentProvider, contentMapper);
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

    bool isKey(TermKeyKey key, uint modifiers, c_long codepoint)
    {
        return (key.type == TermKeyType.UNICODE &&
                key.modifiers == modifiers &&
                key.code.codepoint == codepoint);
    }

    bool processKeypress(TermKeyKey key)
    {
        bool keyWasIgnored = false;

        if(key.modifiers == 0)
        {
            if(key.type == TermKeyType.UNICODE)
            {
                switch(key.code.codepoint)
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
                default:
                    keyWasIgnored = true;
                    break;
                }
            }
            else if(key.type == TermKeyType.KEYSYM)
            {
                switch(key.code.sym)
                {
                case TermKeySym.UP:
                    m_editor.move(ContentEditor.Movement.UP, false);
                    break;
                case TermKeySym.DOWN:
                    m_editor.move(ContentEditor.Movement.DOWN, false);
                    break;
                case TermKeySym.LEFT:
                    m_editor.move(ContentEditor.Movement.LEFT, false);
                    break;
                case TermKeySym.RIGHT:
                    m_editor.move(ContentEditor.Movement.RIGHT, false);
                    break;
                case TermKeySym.HOME:
                    m_editor.move(ContentEditor.Movement.LINEHOME, false);
                    break;
                case TermKeySym.END:
                    m_editor.move(ContentEditor.Movement.LINEEND, false);
                    break;
                case TermKeySym.PAGEUP:
                    m_editor.moveDistance(ContentEditor.Movement.UP, m_editableContentPane.height, false);
                    break;
                case TermKeySym.PAGEDOWN:
                    m_editor.moveDistance(ContentEditor.Movement.DOWN, m_editableContentPane.height, false);
                    break;
                case TermKeySym.DELETE:
                    m_editor.delete_();
                    //updateScrollLimits();
                    //drawMissingLines(m_scrollPositionY, 0, m_height);
                    break;
                default:
                    keyWasIgnored = true;
                    break;
                }
            }
            else if(key.type == TermKeyType.FUNCTION)
            {
                switch(key.code.number)
                {
                case 2:
                    m_mergeResultContentProvider.save();
                    break;
                default:
                    keyWasIgnored = true;
                    break;
                }
            }
        }
        else if(key.modifiers == TermKeyKeyMod.ALT)
        {
            if(key.type == TermKeyType.UNICODE)
            {
                switch(key.code.codepoint)
                {
                case '1':
                    m_editor.toggleCurrentSectionSource(LineSource.A);
                    break;
                case '2':
                    m_editor.toggleCurrentSectionSource(LineSource.B);
                    break;
                case '3':
                    m_editor.toggleCurrentSectionSource(LineSource.C);
                    break;
                default:
                    keyWasIgnored = true;
                    break;
                }
            }
            else if(key.type == TermKeyType.KEYSYM)
            {
                switch(key.code.sym)
                {
                case TermKeySym.UP:
                    m_editor.selectPreviousConflict();
                    break;
                case TermKeySym.DOWN:
                    m_editor.selectNextConflict();
                    break;
                case TermKeySym.PAGEUP:
                    m_editor.selectPreviousUnsolvedConflict();
                    break;
                case TermKeySym.PAGEDOWN:
                    m_editor.selectNextUnsolvedConflict();
                    break;
                default:
                    keyWasIgnored = true;
                    break;
                }
            }
        }
        else if(key.modifiers == TermKeyKeyMod.CTRL)
        {
            if(key.type == TermKeyType.KEYSYM)
            {
                switch(key.code.sym)
                {
                case TermKeySym.HOME:
                    m_editor.move(ContentEditor.Movement.FILEHOME, false);
                    break;
                case TermKeySym.END:
                    m_editor.move(ContentEditor.Movement.FILEEND, false);
                    break;
                default:
                    keyWasIgnored = true;
                    break;
                }
            }
        }
        return !keyWasIgnored;
    }

    void mainLoop()
    {
        /* Refresh stdscr to make sure the static items are drawn and stdscr won't
         * be refreshed again when getch() is called */
        refresh();
        m_inputPanes.redraw();
        m_editableContentPane.redraw();

        TermKey *tk = termkey_new(0, TermKeyFlag.EINTR);
        assert(tk, "Failed to create a new termkey instance");

        TermKeyResult ret;
        TermKeyKey key;

        while( ((ret = termkey_waitkey(tk, &key)) != TermKeyResult.EOF) &&
               !isKey(key, 0, 'q') )
        {
            if(ret == TermKeyResult.ERROR)
            {
                int err = errno();
                log(format("waitkey failed with an error %d", err));
                if(err == EINTR)
                {
                    handleResize();
                }
                else
                {
                    log("it wasn't EINTR, quitting...");
                    break;
                }
            }
            else
            {
                log(format("{ type : %s, { codepoint = %d, number = %d, sym = %s }, modifiers = %d }", (key.type == TermKeyType.UNICODE) ? "UNICODE" :
                                                                                                       (key.type == TermKeyType.FUNCTION) ? "FUNCTION" :
                                                                                                       (key.type == TermKeyType.KEYSYM) ? "KEYSYM" : "OTHER",
                                                                                                       key.code.codepoint,
                                                                                                       key.code.number,
                                                                                                       (key.type == TermKeyType.KEYSYM) ? fromStringz(termkey_get_keyname(tk, key.code.sym)) : "undefined",
                                                                                                       key.modifiers));

                try
                {
                    if(!processKeypress(key))
                    {
                        continue;
                    }
                }
                catch(UserException e)
                {
                    log(format("Showing to the user: '%s'", e.msg));
                }
            }

            if(m_editor.inputFocusNeedsUpdate())
            {
                m_inputPanes.moveFocus(m_editor.getInputFocusPosition());
            }
            if(m_editor.outputFocusNeedsUpdate())
            {
                m_editableContentPane.moveFocus(m_editor.getOutputFocusPosition());
            }

            auto cursorPos = m_editor.getCursorPosition();
            m_editableContentPane.setCursorPosition(cursorPos);

            m_inputPanes.redraw();
            m_editableContentPane.redraw();
        }

        termkey_destroy(tk);
        endwin();

        /* Restore terminal settings to original values */
        tcsetattr(0, TCSANOW, &m_originalTermios);
    }
}
