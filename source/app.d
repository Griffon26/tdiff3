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

import core.thread;
import std.array;
import std.c.locale;
import std.container;
import std.stdio;
import std.string;

import deimos.ncurses.curses;

import common;
import diff;
import fifowriter;
import gnudiff;
import ilineprovider;
import simplefilelineprovider;
import inputpane;

void printDiff3List(Diff3LineList d3ll,
                    shared ILineProvider lpA,
                    shared ILineProvider lpB,
                    shared ILineProvider lpC)
{
    const int columnsize = 30;
    const int linenumsize = 6;
    foreach(d3l; d3ll)
    {
        string lineAText, lineBText, lineCText;
        if(d3l.lineA != -1)
        {
            lineAText = format("%6.6d %-30.30s", d3l.lineA, lpA.get(d3l.lineA).get().replace("\n", "\\n"));
        }
        else
        {
            lineAText = format("%37s", "");
        }
        if(d3l.lineB != -1)
        {
            lineBText = format("%6.6d %-30.30s", d3l.lineB, lpB.get(d3l.lineB).get().replace("\n", "\\n"));
        }
        else
        {
            lineBText = format("%37s", "");
        }
        if(d3l.lineC != -1)
        {
            lineCText = format("%6.6d %-30.30s", d3l.lineC, lpC.get(d3l.lineC).get().replace("\n", "\\n"));
        }
        else
        {
            lineCText = format("%37s", "");
        }
        writefln("%s %s %s", lineAText, lineBText, lineCText);
    }
}



void main()
{
    setlocale(LC_ALL, "");

    const int count = 3;

    shared(SimpleFileLineProvider) lps[count];
    lps[0] = new shared SimpleFileLineProvider("UTF-8-demo.txt");
    lps[1] = new shared SimpleFileLineProvider("dummy_short.txt");
    lps[2] = new shared SimpleFileLineProvider("test_short.txt");

    GnuDiff gnuDiff = new GnuDiff("/tmp");
    gnuDiff.setFile(0, lps[0]);
    gnuDiff.setFile(1, lps[1]);
    gnuDiff.setFile(2, lps[2]);

    writefln("Starting diff");

    /* TODO:
       Always keep functions like runDiff and calcDiff3LineListUsingAB such
       that they can be applied to regions within manual diff alignments. 
       That way we can hopefully avoid having to correct the manual diff
       alignments and we can also prevent having to rediff everything when
       manual diff alignments are added or removed.
     */

    writefln("diffing 0 and 1");
    auto diffList12 = gnuDiff.runDiff(0, 1, 0, -1, 0, -1);
    writefln("diffing 0 and 2");
    auto diffList13 = gnuDiff.runDiff(0, 2, 0, -1, 0, -1);
    writefln("diffing 1 and 2");
    auto diffList23 = gnuDiff.runDiff(1, 2, 0, -1, 0, -1);

    writefln("diff.calcDiff3LineList");
    auto diff3LineList = diff.calcDiff3LineList(diffList12, diffList13, diffList23);
    writefln("validateDiff3LineListForN");
    validateDiff3LineListForN(diff3LineList, 0, 0, lps[0].getLastLineNumber());
    validateDiff3LineListForN(diff3LineList, 1, 0, lps[1].getLastLineNumber());
    validateDiff3LineListForN(diff3LineList, 2, 0, lps[2].getLastLineNumber());

//    printDiff3List(diff3LineList, lps[0], lps[1], lps[2]);

    writefln("trimDiff3LineList");
    trimDiff3LineList(diff3LineList, lps[0], lps[1], lps[2]);

    /* TODO: finediff */

    writefln("print");
    //printDiff3List(diff3LineList, lps[0], lps[1], lps[2]);

    writefln("Cleaning up");

    gnuDiff.cleanup();

    //Thread.sleep(dur!("seconds")(50));

    initscr();
    cbreak();
    noecho();
    refresh();

    int line_offset = 0;

    int win_start_x = 0;
    int win_start_y = 1;
    int xsize = COLS / 2;
    int ysize = LINES - 1;

    int pad_start_x = win_start_x + 1;
    int pad_start_y = win_start_y + 1;
    int pad_xsize = xsize - 2;
    int pad_ysize = ysize - 2;


    auto inputPane = new InputPane(win_start_x, win_start_y, xsize, ysize, lps[0].getMaxWidth() + 1, lps[0].getLastLineNumber() + 1);
    auto missingLineTuple = inputPane.beginMissingLineUpdate();

    for(int y = missingLineTuple[0]; y < missingLineTuple[0] + missingLineTuple[1]; y++)
    {
        inputPane.addMissingLine(y, lps[0].get(y));
    }
    inputPane.endMissingLineUpdate();
    inputPane.redrawAll();

    auto right_win = newwin(ysize, COLS - xsize, 1, xsize);
    box(right_win, 0 , 0);
    wrefresh(right_win);


    auto right_pad = newpad(LINES - 3, xsize - 2);
    scrollok(right_pad, true);
    wprintw(right_pad, toStringz(format("maxwidth is %d\n", lps[0].getMaxWidth())));
    prefresh(right_pad, 0, 0, 2, xsize + 2, LINES - 2, COLS - 2);

    int ch = 'x';
    while(ch != 'q')
    {
        ch = getch();

        switch(ch)
        {
        case 'j':
            inputPane.scrollY(1);
            break;
        case 'i':
            inputPane.scrollY(-1);
            break;
        case 'k':
            wprintw(right_pad, "scrolling left\n");
            inputPane.scrollX(-1);
            break;
        case 'l':
            wprintw(right_pad, "scrolling right\n");
            inputPane.scrollX(1);
            break;
        default:
            break;
        }

        missingLineTuple = inputPane.beginMissingLineUpdate();
        for(int y = missingLineTuple[0]; y < missingLineTuple[0] + missingLineTuple[1]; y++)
        {
            inputPane.addMissingLine(y, lps[0].get(y));
        }
        inputPane.endMissingLineUpdate();
        inputPane.redrawAll();

        prefresh(right_pad, 0, 0, 2, xsize + 2, LINES - 2, COLS - 2);
    }
    endwin();
}

