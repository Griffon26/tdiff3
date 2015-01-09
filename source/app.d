import core.thread;
import std.array;
import std.c.locale;
import std.container;
import std.stdio;
import std.string;

import ncurses;

import common;
import diff;
import fifowriter;
import gnudiff;
import ilineprovider;
import simplefilelineprovider;

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
    const int count = 3;

    shared(SimpleFileLineProvider) lps[count];
    lps[0] = new shared SimpleFileLineProvider("/home/griffon26/UTF-8-demo.txt");
    lps[1] = new shared SimpleFileLineProvider("/home/griffon26/git/kdiff3/kdiff3/src-QT4/dummy_short.txt");
    lps[2] = new shared SimpleFileLineProvider("/home/griffon26/git/kdiff3/kdiff3/src-QT4/test_short.txt");

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
    printDiff3List(diff3LineList, lps[0], lps[1], lps[2]);

    writefln("Cleaning up");

    gnuDiff.cleanup();

    writefln("Exiting main");

    setlocale(LC_ALL, "");
    initscr();          //Start curses mode

    int line_offset = 0;

    int xsize = COLS / 2;
    int ysize = LINES - 1;
    auto left_win = newwin(ysize, xsize, 1, 0);
    scrollok(left_win, true);
    box(left_win, 0 , 0);
    for(int y = 0; y < ysize - 1; y++)
    {
        wprintw(left_win, toStringz(lps[0].get(line_offset + y)));
    }
    wrefresh(left_win);

    auto right_win = newwin((LINES - 1), COLS / 2, 1, COLS / 2);
    scrollok(right_win, true);
    box(right_win, 0 , 0);
    wrefresh(right_win);

    int ch = 'x';
    while(ch != 'q')
    {
        ch = getch();
        
        switch(ch)
        {
        case 'j':
            line_offset++; 
            wprintw(left_win, toStringz(lps[0].get(line_offset + ysize - 1)));
            wrefresh(left_win);
            break;
        case 'i':
            line_offset--;
            wscrl(left_win, -1);
            wprintw(left_win, toStringz(lps[0].get(line_offset)));
            wrefresh(left_win);
            break;
        default:
            break;
        }
    }
    endwin();
}

