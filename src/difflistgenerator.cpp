/*
 * tdiff3 - a text-based 3-way diff/merge tool that can handle large files
 * Copyright (C) 2016  Maurice van der Pot <griffon26@kfk4ever.com>
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

#include <exception>

#include "common.h"
#include "difflistgenerator.h"

//import gnudiff;
//import ilineprovider;
//import myassert;


struct HashedLine
{
private:
    ILineProvider m_lp;
    int m_lineNumber;

public:
    HashedLine(ILineProvider lp, int lineNumber)
    {
        m_lp = lp;
        m_lineNumber = lineNumber;
    }

    const hash_t toHash() nothrow
    {
        scope(failure) assert(0);

        string result = getLine();
        return typeid(string).getHash(&result);
    }

    const string getLine()
    {
        return (cast(ILineProvider)(m_lp)).get(m_lineNumber).text;
    }

    bool opEquals(ref const HashedLine other) const
    {
        return getLine() == other.getLine();
    }
}

lin[][MAX_NR_OF_FILES] createLineEquivalenceLists(ILineProvider[MAX_NR_OF_FILES] lineProviders, lin *p_equivMax)
{
    lin[][MAX_NR_OF_FILES] equivs;
    lin[HashedLine] hashmap;

    for(int lpIndex = 0; lpIndex < 3; lpIndex++)
    {
        writefln("Hashing lines of file %d", lpIndex);
        int i = 0;
        while(lineProviders[lpIndex].get(i).count != 0)
        {
            lin equivid;
            HashedLine l = HashedLine(lineProviders[lpIndex], i);
            if(l !in hashmap)
            {
                equivid = hashmap[l] = hashmap.length;
            }
            else
            {
                equivid = hashmap[l];
            }
            equivs[lpIndex] ~= equivid;
            i++;
        }
    }

    *p_equivMax = hashmap.length;
    return equivs;
}

struct DiffListContext
{
    int currentLine0;
    int currentLine1;
    DiffList diffList;
};

extern(C) void addHunkToDiffList(int first0, int last0, int first1, int last1, void *pContext)
{
    auto dlContext = cast(DiffListContext *)(pContext);

    first0--;
    last0--;
    first1--;
    last1--;

    Diff d = Diff(0, 0, 0);
    d.nofEquals = first0 - dlContext.currentLine0;
    assertEqual(d.nofEquals, first1 - dlContext.currentLine1);
    d.diff1 = last0 + 1 - first0;
    d.diff2 = last1 + 1 - first1;

    dlContext.currentLine0 += d.nofEquals + d.diff1;
    dlContext.currentLine1 += d.nofEquals + d.diff2;

    dlContext.diffList.insertBack(d);
}

DiffList diffPair(lin[] source0, lin[] source1, lin equivMax)
{
    comparison cmp;

    cmp.file[0].buffered_lines = source0.length;
    cmp.file[0].prefix_lines = 0;
    cmp.file[0].equivs = &source0[0];
    cmp.file[0].equiv_max = equivMax;

    cmp.file[1].buffered_lines = source1.length;
    cmp.file[1].prefix_lines = 0;
    cmp.file[1].equivs = &source1[0];
    cmp.file[1].equiv_max = equivMax;

    DiffListContext dlContext;
    dlContext.currentLine0 = 0;
    dlContext.currentLine1 = 0;

    setHunkCallback(&addHunkToDiffList, &dlContext);

    int ret = diff_2_files(&cmp);

    int remainingLines1 = to!int(source0.length) - dlContext.currentLine0;
    int remainingLines2 = to!int(source1.length) - dlContext.currentLine1;
    assertEqual(remainingLines1, remainingLines2, "Remaining lines not the same for the two files");
    if(remainingLines1 > 0)
    {
        dlContext.diffList.insertBack(Diff(remainingLines1, 0, 0));
    }

    verifyDiffList(dlContext.diffList, to!int(source0.length), to!int(source1.length));

    return dlContext.diffList;
}

DiffList[MAX_NR_OF_FILES] generateDiffLists(ILineProvider[MAX_NR_OF_FILES] lineProviders)
{
    lin equivMax;
    auto equivs = createLineEquivalenceLists(lineProviders, &equivMax);

    DiffList[MAX_NR_OF_FILES] dls;

    foreach(idx, sources; [ [equivs[0], equivs[1]],
                            [equivs[0], equivs[2]],
                            [equivs[1], equivs[2]] ])
    {
        writefln("Diffing pair of files nr %d", idx);
        dls[idx] = diffPair(sources[0], sources[1], equivMax);
    }

    return dls;
}

static void verifyDiffList(DiffList diffList, int size1, int size2)
{
    int l1 = 0;
    int l2 = 0;

    foreach(entry; diffList)
    {
        l1 += entry.nofEquals + entry.diff1;
        l2 += entry.nofEquals + entry.diff2;
    }

    assertEqual(l1, size1);
    assertEqual(l2, size2);
}

