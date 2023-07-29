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
#include <cassert>
#include <fcntl.h>
#include <stdexcept>
#include <string_view>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include "mmappedfilelineprovider.h"


class OpenedFile
{
public:
    explicit OpenedFile(const char *filename, int flags):
        mFd(open(filename, flags))
    {
        if(mFd == -1)
        {
            throw std::runtime_error("Failed to open file");
        }
    }

    ~OpenedFile()
    {
        if(mFd != -1)
        {
            close(mFd);
        }
    }

    int fd() const
    {
        return mFd;
    }

    size_t size() const
    {
        struct stat statbuf;
        if(fstat(mFd, &statbuf) == -1)
        {
            throw std::runtime_error("Failed to get file size");
        }
        return statbuf.st_size;
    }

private:
    int mFd;
};

class MemoryMap
{
public:
    MemoryMap(const OpenedFile& f):
        mSize(f.size()),
        mMap(mmap(NULL, mSize, PROT_READ, MAP_PRIVATE, f.fd(), 0))
    {
        if(mMap == MAP_FAILED)
        {
            throw std::runtime_error("Failed to map file");
        }
    }

    ~MemoryMap()
    {
        if(mMap != MAP_FAILED)
        {
            munmap(mMap, mSize);
        }
    }

    size_t size() const
    {
        return mSize;
    }

    std::string_view getView(size_t from, size_t to)
    {
        assert(from <= mSize);
        assert(to <= mSize);
        assert(to < from);
        return std::string_view(static_cast<char *>(mMap) + from, to - from);
    }

private:
    size_t mSize;
    void *mMap;

};

MmappedFileLineProvider::MmappedFileLineProvider(const std::string& filename):
    m_file(std::make_unique<MemoryMap>(OpenedFile(filename.c_str(), O_RDONLY)))
{
    m_fileLength = m_file->size();
    m_filename = filename;
}

MmappedFileLineProvider::~MmappedFileLineProvider()
{
}

size_t MmappedFileLineProvider::countTabs(const char *from, const char *to)
{
    int count = 0;
    for(const char *pChar = from; pChar < to; pChar++)
    {
        if(*pChar == '\t')
        {
            count++;
        }
    }
    return count;
}

void MmappedFileLineProvider::ensure_line_is_available(int index)
{
    /* index already accessible */
    if(index < m_lineEnds.size())
    {
        return;
    }

    //writefln("%s: ensure %d", m_filename, index);

    auto lastpos = (m_lineEnds.size() == 0) ? 0 : m_lineEnds.size() - 1;

    /* already have indices for all content */
    if(lastpos == m_fileLength)
    {
        return;
    }

    //writeln("ensure ", index);

    while(lastpos < m_fileLength && m_lineEnds.size() < index + readahead + 1)
    {
        auto restOfFile = m_file->getView(lastpos, m_fileLength);
        auto lineEndIndex = restOfFile.find('\n');
        if(lineEndIndex == std::string_view::npos)
        {
            lineEndIndex = restOfFile.size();
        }
        else
        {
            lineEndIndex += 1;
        }
        lastpos += lineEndIndex;
        m_lineEnds.push_back(lastpos);

        auto maxWidth = countTabs(&restOfFile[0], &restOfFile[lineEndIndex + 1]) * 7 + lineEndIndex;
        if(maxWidth > m_maxWidth)
        {
            m_maxWidth = maxWidth;
        }
    }

    //writefln("%s: m_filename: lastpos is %d, file length is %d, number of lines is %d", m_filename, lastpos, m_fileLength, m_lineEnds.length);
}

size_t MmappedFileLineProvider::getLastLineNumber()
{
    assert(m_lineEnds.back() == m_fileLength);
    return m_lineEnds.size() - 1;
}

int MmappedFileLineProvider::getMaxWidth()
{
    return m_maxWidth;
}

std::vector<std::string_view> MmappedFileLineProvider::get(int i)
{
    std::vector<std::string_view> result;
    ensure_line_is_available(i);

    if(i < m_lineEnds.size())
    {
        auto lineStart = (i == 0) ? 0 : m_lineEnds[i - 1];
        auto lineEnd = m_lineEnds[i];
        result.push_back(m_file->getView(lineStart, lineEnd));
    }

    return result;
}

#if 0
std::vector<std::string_view> MmappedFileLineProvider::get(int firstLine, int lastLine)
{
    auto result;
    ensure_line_is_available(lastLine);

    if(firstLine < m_lineEnds.size())
    {
        auto lineStart = (firstLine == 0) ? 0 : m_lineEnds[firstLine - 1];
        auto lineEnd = lastLine > m_lineEnds.size() ? m_lineEnds.back() : m_lineEnds[lastLine];
        result.push_back(
        result.count = lastLine - firstLine + 1;
        result.text = to!string(m_file[lineStart..lineEnd]);
    }
    else
    {
        result.text = "";
        result.count = 0;
    }

    return result;
}
#endif

