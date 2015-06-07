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
 *
 * <object data="uml/app.svg" type="image/svg+xml"></object>
 */
/*
 * @startuml
 * hide circle
 * skinparam minClassWidth 70
 * skinparam classArrowFontSize 8
 * Ui --> ContentEditor: sends editing commands\ngets focus/cursor position
 * Ui --> InputPanes: sets focus position
 * Ui --> EditableContentPane: sets focus/cursor position
 * ContentEditor --> ContentMapper: applies modifications\nrequests section location\ngets line source
 * ContentEditor --> "3" HighlightAddingContentProvider1: sets input lines to be highlighted
 * ContentEditor --> "1" HighlightAddingContentProvider2: sets output lines to be highlighted
 * ContentEditor --> ILineProvider: gets line
 * InputPanes --> "3" HighlightAddingContentProvider1: gets content
 * InputPanes --> "3" LineNumberContentProvider: gets content
 * EditableContentPane --> HighlightAddingContentProvider2: gets content
 * HighlightAddingContentProvider1 --> Diff3ContentProvider: gets content
 * HighlightAddingContentProvider2 --> MergeResultContentProvider: gets content
 * MergeResultContentProvider --> ContentMapper: gets line source
 * MergeResultContentProvider --> "3" ILineProvider: gets line
 * Diff3ContentProvider --> ILineProvider: gets line
 *
 * url of Ui is [[../ui/Ui.html]]
 * url of InputPanes is [[../inputpanes/InputPanes.html]]
 * url of ContentEditor is [[../contenteditor/ContentEditor.html]]
 * url of EditableContentPane is [[../editablecontentpane/EditableContentPane.html]]
 * url of LineNumberContentProvider is [[../linenumbercontentprovider/LineNumberContentProvider.html]]
 * url of HighlightAddingContentProvider1 is [[../highlightaddingcontentprovider/HighlightAddingContentProvider.html]]
 * url of HighlightAddingContentProvider2 is [[../highlightaddingcontentprovider/HighlightAddingContentProvider.html]]
 * url of Diff3ContentProvider is [[../diff3contentprovider/Diff3ContentProvider.html]]
 * url of MergeResultContentProvider is [[../mergeresultcontentprovider/MergeResultContentProvider.html]]
 * url of ILineProvider is [[../ilineprovider/ILineProvider.html]]
 * url of ContentMapper is [[../contentmapper/ContentMapper.html]]
 * @enduml
 */
module app;

import std.algorithm;
import std.c.locale;
import std.conv;
import std.math;
import std.stdio;

import common;
import contentmapper;
import diff;
import diff3contentprovider;
import gnudiff;
import icontentprovider;
import iformattedcontentprovider;
import linenumbercontentprovider;
import mergeresultcontentprovider;
import simplefilelineprovider;
import ui;

void main()
{
    setlocale(LC_ALL, "");

    const int count = 3;

    shared(SimpleFileLineProvider) lps[count];
    //lps[0] = new shared SimpleFileLineProvider("UTF-8-demo.txt");
    //lps[1] = new shared SimpleFileLineProvider("UTF-8-demo2.txt");
    //lps[2] = new shared SimpleFileLineProvider("test_short.txt");
    lps[0] = new shared SimpleFileLineProvider("/home/griffon26/unison/projects/2014/tdiff3/base.txt");
    lps[1] = new shared SimpleFileLineProvider("/home/griffon26/unison/projects/2014/tdiff3/contrib1.txt");
    lps[2] = new shared SimpleFileLineProvider("/home/griffon26/unison/projects/2014/tdiff3/contrib2.txt");

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

    writefln("trimDiff3LineList");
    trimDiff3LineList(diff3LineList, lps[0], lps[1], lps[2]);
    //printDiff3List(diff3LineList, lps[0], lps[1], lps[2]);

    determineFineDiffStyle(diff3LineList, lps[0], lps[1], lps[2]);
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

    IFormattedContentProvider[3] cps;
    cps[0] = new Diff3ContentProvider(nrOfColumns, nrOfLines, d3la, 0, lps[0]);
    cps[1] = new Diff3ContentProvider(nrOfColumns, nrOfLines, d3la, 1, lps[1]);
    cps[2] = new Diff3ContentProvider(nrOfColumns, nrOfLines, d3la, 2, lps[2]);

    IContentProvider[3] lnps;
    lnps[0] = new LineNumberContentProvider(lineNumberWidth, nrOfLines, d3la, 0);
    lnps[1] = new LineNumberContentProvider(lineNumberWidth, nrOfLines, d3la, 1);
    lnps[2] = new LineNumberContentProvider(lineNumberWidth, nrOfLines, d3la, 2);

    auto contentMapper = new ContentMapper();
    contentMapper.determineMergeResultSections(d3la);
    contentMapper.automaticallyResolveConflicts(d3la);

    auto mergeResultContentProvider = new MergeResultContentProvider(contentMapper, lps[0], lps[1], lps[2]);

    auto ui = new Ui(cps, lnps, mergeResultContentProvider, contentMapper);
    ui.handleResize();
    ui.mainLoop();
}

