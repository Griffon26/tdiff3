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
module fifowriter;

import core.sys.posix.unistd;
import std.conv;
import std.stdio;

import ilineprovider;

/**
 * FifoWriter allows block-wise writing of data from an ILineProvider to a
 * specified file descriptor. In order to write all data the write function
 * must be called in a loop until the eof function returns true.
 */
class FifoWriter
{
private:
    ILineProvider m_lp;
    int m_fifoFd;
    string m_buffer;
    int m_linesRead;
    long m_bytesWritten;
    bool m_lastLineRead;

public:
    this(ILineProvider lp, int fifoFd)
    {
        m_lp = lp;
        m_fifoFd = fifoFd;
    }

    void write()
    {
        immutable int linesPerIteration = 10000;

        if(m_bytesWritten == m_buffer.length)
        {
            m_bytesWritten = 0;

            auto lines = m_lp.get(m_linesRead, m_linesRead + linesPerIteration - 1);
            if(lines.count != linesPerIteration)
            {
                m_lastLineRead = true;
            }
            //writefln("%d: read %d lines (%d - %d), %d bytes", m_fifoFd, lines.count, m_linesRead, m_linesRead + lines.count - 1, lines.text.length);
            m_buffer = lines.text;
            m_linesRead += lines.count;
        }

        long bytesWrittenThisTime = core.sys.posix.unistd.write(m_fifoFd, &m_buffer[m_bytesWritten], m_buffer.length - m_bytesWritten);
        //writefln("%d: wrote %d bytes", m_fifoFd, bytesWrittenThisTime);
        m_bytesWritten += bytesWrittenThisTime;
    }

    bool eof()
    {
        return (m_bytesWritten == m_buffer.length) && m_lastLineRead;
    }
}

class FifoReader
{
private:
    int m_fifoFd;
    string m_text;
    bool m_eof;

public:
    this(int fifoFd)
    {
        m_fifoFd = fifoFd;
    }

    void read()
    {
        char[4196] m_buffer;
        long bytesReadThisTime = core.sys.posix.unistd.read(m_fifoFd, &m_buffer[0], m_buffer.length);
        if(bytesReadThisTime == 0)
        {
            m_eof = true;
        }
        else
        {
            m_text ~= to!string(m_buffer[0..bytesReadThisTime]);
        }
    }

    bool eof()
    {
        return m_eof;
    }

    string getText()
    {
        return m_text;
    }
}

