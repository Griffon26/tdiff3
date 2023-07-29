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

#include <cassert>
#include <exception>
#include <unordered_map>

#include "common.h"
#include "difflistgenerator.h"

#include "gnudiff.h"
#include "ilineprovider.h"
//import myassert;


struct HashedLine
{
private:
    ILineProvider& m_lp;
    int m_lineNumber;

public:
    HashedLine(ILineProvider& lp, int lineNumber):
        m_lp(lp),
        m_lineNumber(lineNumber)
    {
    }

    const std::string_view getLine() const
    {
        return m_lp.get(m_lineNumber)[0];
    }

    bool operator==(const HashedLine& other) const
    {
        return getLine() == other.getLine();
    }
};

namespace std
{
    template <>
    class hash<HashedLine>
    {
    public:
        std::uint64_t operator()(const HashedLine& hashedLine) const
        {
            return std::hash<std::string_view>()(hashedLine.getLine());
        }
    };
}

std::vector<std::vector<lin>> createLineEquivalenceLists(const std::vector<ILineProvider*>& lineProviders, lin *p_equivMax)
{
    std::vector<std::vector<lin>> equivs;
    std::unordered_map<HashedLine, lin> hashmap;

    for(size_t lpIndex = 0; lpIndex < lineProviders.size(); lpIndex++)
    {
        printf("Hashing lines of file %lu", lpIndex);
        assert(lineProviders[lpIndex] != nullptr);

        int i = 0;
        while(lineProviders[lpIndex]->get(i).size() != 0)
        {
            lin equivid;
            HashedLine l = HashedLine(*(lineProviders[lpIndex]), i);
            auto it = hashmap.find(l);
            if(it == hashmap.end())
            {
                equivid = hashmap[l] = hashmap.size();
            }
            else
            {
                equivid = it->second;
            }
            equivs[lpIndex].push_back(equivid);
            i++;
        }
    }

    *p_equivMax = hashmap.size();
    return equivs;
}

struct DiffListContext
{
    int currentLine0;
    int currentLine1;
    DiffList diffList;
};

extern "C" void addHunkToDiffList(int first0, int last0, int first1, int last1, void *pContext)
{
    auto dlContext = static_cast<DiffListContext *>(pContext);

    first0--;
    last0--;
    first1--;
    last1--;

    Diff d = Diff(0, 0, 0);
    d.nofEquals = first0 - dlContext->currentLine0;
    assert(d.nofEquals == first1 - dlContext->currentLine1);
    d.diff1 = last0 + 1 - first0;
    d.diff2 = last1 + 1 - first1;

    dlContext->currentLine0 += d.nofEquals + d.diff1;
    dlContext->currentLine1 += d.nofEquals + d.diff2;

    dlContext->diffList.push_back(d);
}

DiffList diffPair(std::vector<lin> source0, std::vector<lin> source1, lin equivMax)
{
    comparison cmp;

    cmp.file[0].buffered_lines = source0.size();
    cmp.file[0].prefix_lines = 0;
    cmp.file[0].equivs = &source0[0];
    cmp.file[0].equiv_max = equivMax;

    cmp.file[1].buffered_lines = source1.size();
    cmp.file[1].prefix_lines = 0;
    cmp.file[1].equivs = &source1[0];
    cmp.file[1].equiv_max = equivMax;

    DiffListContext dlContext;
    dlContext.currentLine0 = 0;
    dlContext.currentLine1 = 0;

    setHunkCallback(&addHunkToDiffList, &dlContext);

    int ret = diff_2_files(&cmp);

    // TODO: check if we can use size_t everywhere instead of int
    int remainingLines1 = static_cast<int>(source0.size()) - dlContext.currentLine0;
    int remainingLines2 = static_cast<int>(source1.size()) - dlContext.currentLine1;
    assert(remainingLines1 == remainingLines2); // Remaining lines not the same for the two files
    if(remainingLines1 > 0)
    {
        dlContext.diffList.push_back(Diff(remainingLines1, 0, 0));
    }

    verifyDiffList(dlContext.diffList, static_cast<int>(source0.size()), static_cast<int>(source1.size()));

    return dlContext.diffList;
}

std::vector<DiffList> generateDiffLists(const std::vector<ILineProvider*>& lineProviders)
{
    lin equivMax;
    auto equivs = createLineEquivalenceLists(lineProviders, &equivMax);

    std::vector<DiffList> dls;
    int comparisons[3][2] = {
        { 0, 1 },
        { 0, 2 },
        { 1, 2 }
    };

    for(auto pair: comparisons)
    {
        printf("Diffing pair of files %d vs %d", pair[0], pair[1]);
        dls.push_back(diffPair(equivs[pair[0]], equivs[pair[1]], equivMax));
    }

    return dls;
}

void verifyDiffList(DiffList& diffList, int size1, int size2)
{
    int l1 = 0;
    int l2 = 0;

    for(auto &entry: diffList)
    {
        l1 += entry.nofEquals + entry.diff1;
        l2 += entry.nofEquals + entry.diff2;
    }

    assert(l1 == size1);
    assert(l2 == size2);
}

