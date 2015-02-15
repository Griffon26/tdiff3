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
module app;

import std.algorithm;
import std.array;
import std.c.locale;
import std.conv;
import std.math;
import std.stdio;
import std.string;

import common;
import diff;
import diff3contentprovider;
import gnudiff;
import icontentprovider;
import ilineprovider;
import linenumbercontentprovider;
import modifiedcontentprovider;
import simplefilelineprovider;
import ui;

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
    lps[1] = new shared SimpleFileLineProvider("UTF-8-demo2.txt");
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

    fineDiff(diff3LineList, DiffSelection.A_vs_B, lps[0], lps[1]);
    fineDiff(diff3LineList, DiffSelection.A_vs_C, lps[0], lps[2]);
    fineDiff(diff3LineList, DiffSelection.B_vs_C, lps[1], lps[2]);

    mergeFineDiffs(diff3LineList, 0);
    mergeFineDiffs(diff3LineList, 1);
    mergeFineDiffs(diff3LineList, 2);

    //writefln("print");
    //printDiff3List(diff3LineList, lps[0], lps[1], lps[2]);

    writefln("Cleaning up");

    gnuDiff.cleanup();



    auto d3la = Diff3LineArray(diff3LineList[]);
    int nrOfLines = to!int(d3la.length);
    int nrOfColumns = max(lps[0].getMaxWidth() + 1,
                          lps[1].getMaxWidth() + 1,
                          lps[2].getMaxWidth() + 1);
    int lineNumberWidth = to!int(trunc(log10(nrOfLines))) + 1;
    writefln("nr of lines in d3la is %d\n", nrOfLines);

    IContentProvider[3] cps;
    cps[0] = new Diff3ContentProvider(nrOfColumns, nrOfLines, d3la, 0, lps[0]);
    cps[1] = new Diff3ContentProvider(nrOfColumns, nrOfLines, d3la, 1, lps[1]);
    cps[2] = new Diff3ContentProvider(nrOfColumns, nrOfLines, d3la, 2, lps[2]);

    IContentProvider[3] lnps;
    lnps[0] = new LineNumberContentProvider(lineNumberWidth, nrOfLines, d3la, 0);
    lnps[1] = new LineNumberContentProvider(lineNumberWidth, nrOfLines, d3la, 1);
    lnps[2] = new LineNumberContentProvider(lineNumberWidth, nrOfLines, d3la, 2);

    auto modifiedContentProvider = new ModifiedContentProvider(lps[0]);

    auto ui = new Ui(cps, lnps, modifiedContentProvider);
    ui.handleResize();
    ui.mainLoop();
}

