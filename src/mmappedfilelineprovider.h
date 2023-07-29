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

/**
 * This is a temporary implementation of a line provider that reads lines from a file.
 * It caches the positions of line endings to avoid having to parse the entire
 * file again and again.
 * As the name says the implementation is very simple and just reads the entire
 * file into memory first. This implementation will have to be replaced by one
 * that limits the amount of memory it uses (either by caching part of the file
 * or by using mmap).
 */
#pragma once

#include <memory>
#include <string>

#include "ilineprovider.h"

class MemoryMap;

class MmappedFileLineProvider: public ILineProvider
{
public:
    MmappedFileLineProvider(const std::string& filename);
    virtual ~MmappedFileLineProvider();

    virtual size_t getLastLineNumber() override;
    int getMaxWidth();
    virtual std::vector<std::string_view> get(size_t i) override;
    //std::vector<std::string_view> get(int firstLine, int lastLine);

private:
    size_t countTabs(const char *from, const char *to);
    void ensure_line_is_available(int index);

private:
    static const int readahead = 10000;
    int m_maxWidth;
    std::vector<size_t> m_lineEnds;
    std::unique_ptr<MemoryMap> m_file;
    ulong m_fileLength;
    std::string m_filename;

};


