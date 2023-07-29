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
 * Ui --> SectionNavigator: sends section navigation commands\ngets focus/cursor position
 * Ui --> ContentEditor: sends editing commands\nsends cursor navigation commands\ngets focus/cursor position
 * Ui --> InputPanes: sets focus position
 * Ui --> EditableContentPane: sets focus/cursor position
 * SectionNavigator --> ContentMapper: requests section location
 * SectionNavigator --> "3" HighlightAddingContentProvider1: sets input lines to be highlighted
 * SectionNavigator --> "1" HighlightAddingContentProvider2: sets output lines to be highlighted
 * ContentEditor --> ContentMapper: applies modifications
 * ContentEditor --> MergeResultContentProvider: gets line
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

#include <iostream>
#include <string>
#include "cxxopts.hpp"

#include "difflistgenerator.h"
#include "mmappedfilelineprovider.h"


int main(int argc, char *argv[])
{
    //setlocale(LC_ALL, "");

    std::vector<std::string> inputFileNames;
    std::string outputFileName;

    try
    {
        cxxopts::Options options("tdiff3", "A text-based 3-way diff/merge tool that can handle large files.");

        options.add_options()
            ("o,output", "The output file of the merge", cxxopts::value<std::string>())
            ("infiles", "Input files", cxxopts::value<std::vector<std::string>>())
            ("h,help", "Print this help message and exit")
        ;

        auto result = options.parse(argc, argv);

        if (result.count("help"))
        {
            std::cout << options.help() << std::endl;
            exit(0);
        }
        if (!result.count("infiles") || 
            (result["infiles"].as<std::vector<std::string>>().size() != 3) ||
            !result.count("output"))
        {
            std::cerr << "Please specify 3 input files and an output file on the command line\n";
            exit(-1);
        }
        inputFileNames = result["infiles"].as<std::vector<std::string>>();
        outputFileName = result["output"].as<std::string>();
    }
    catch(cxxopts::exceptions::parsing e)
    {
        std::cerr << e.what();
        exit(-1);
    }

    std::cout << "Input file 1: " << inputFileNames[0] << "\n";
    std::cout << "Input file 2: " << inputFileNames[1] << "\n";
    std::cout << "Input file 3: " << inputFileNames[2] << "\n";
    std::cout << "Output file : " << outputFileName << "\n";

    const int count = 3;

    std::unique_ptr<MmappedFileLineProvider> lps[count];
    lps[0] = std::make_unique<MmappedFileLineProvider>(inputFileNames[0]);
    lps[1] = std::make_unique<MmappedFileLineProvider>(inputFileNames[1]);
    lps[2] = std::make_unique<MmappedFileLineProvider>(inputFileNames[2]);
    std::vector<ILineProvider*> lpsVector{lps[0].get(), lps[1].get(), lps[2].get()};

    auto diffLists = generateDiffLists(lpsVector);
#if 0
    auto diffList12 = diffLists[0];
    auto diffList13 = diffLists[1];
    auto diffList23 = diffLists[2];

    writefln("diff.calcDiff3LineList");
    auto diff3LineList = diff.calcDiff3LineList(diffList12, diffList13, diffList23);

    /* Now that we no longer need them, clear the difflists to free up memory */
    diffList12.clear();
    diffList13.clear();
    diffList23.clear();

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
    contentMapper.automaticallyResolveDifferences(d3la);

    auto mergeResultContentProvider = new MergeResultContentProvider(contentMapper, lps[0], lps[1], lps[2], outputFileName);

    auto ui = new Ui(cps, lnps, mergeResultContentProvider, contentMapper);
    ui.handleResize();
    ui.mainLoop();
#endif
}

