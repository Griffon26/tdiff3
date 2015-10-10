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
module gnudiff;

import std.conv;
import std.exception;
import std.process;
import std.regex;
import std.stdio;
import std.string;

import core.stdc.errno;
import core.sys.posix.fcntl;
import core.sys.posix.poll;
import core.sys.posix.unistd;

import common;
import fifowriter;
import ilineprovider;
import myassert;


const uint MAX_NR_OF_FILES = 3;

/**
 * GnuDiff performs a _diff between the data from two ILineProviders. It does
 * this by spawning an external _diff process and having it read from named
 * pipes that two FifoWriters will be writing to.
 */
class GnuDiff
{
private:
    string m_tempdir;
    ILineProvider[MAX_NR_OF_FILES] m_lineProviders;

public:
    this(string tempdir)
    {
        m_tempdir = tempdir;
    }

    void setFile(uint n, ILineProvider lp)
    {
        assert(n < MAX_NR_OF_FILES);

        m_lineProviders[n] = lp;
    }

    void cleanup()
    {
        for(int index = 0; index < MAX_NR_OF_FILES; index++)
        {
            removeFifo(getFifoName(index));
        }
    }

    private string getFifoName(uint n)
    {
        assert(n < MAX_NR_OF_FILES);
        return format("%s/diff_input_%d", m_tempdir, n);
    }

    DiffList runDiff(uint n1, uint n2,
                     int firstLine1, int lastLine1,
                     int firstLine2, int lastLine2)
    {
        assert(n1 < MAX_NR_OF_FILES);
        assert(n2 < MAX_NR_OF_FILES);

        auto difflines = diff_2_files(n1, n2, firstLine1, lastLine2, firstLine2, lastLine2);

        /* If a last line was -1, then we've read the entire file by now and we
         * can ask the line provider what was really the last line */
        if(lastLine1 == -1) lastLine1 = m_lineProviders[n1].getLastLineNumber();
        if(lastLine2 == -1) lastLine2 = m_lineProviders[n2].getLastLineNumber();

        writefln("lastline1 = %d", lastLine1);
        writefln("lastline2 = %d", lastLine2);

        DiffList diffList = gnudiff_2_difflist(difflines,
                                               lastLine1 - firstLine1 + 1,
                                               lastLine2 - firstLine2 + 1);

        return diffList;
    }

    private static Diff gnudiffhunk_2_diff(string hunk, ref int currentLine1, ref int currentLine2)
    {
        auto m = match(hunk, regex(r"^(?P<leftFrom>\d+)(,(?P<leftTo>\d+))?(?P<oper>[acd])(?P<rightFrom>\d+)(,(?P<rightTo>\d+))?$"));
        enforce(m, format("Didn't find a match on line '%s'", hunk));

        /* line numbers in difflines are 1-based, so subtract 1 asap */
        int leftFrom = to!int(m.captures["leftFrom"]) - 1;
        int rightFrom = to!int(m.captures["rightFrom"]) - 1;
        int leftCount = 1;
        int rightCount = 1;

        if(m.captures["leftTo"].length != 0)
        {
            int leftTo = to!int(m.captures["leftTo"]) - 1;
            leftCount = leftTo - leftFrom + 1;
        }

        if(m.captures["rightTo"].length != 0)
        {
            int rightTo = to!int(m.captures["rightTo"]) - 1;
            rightCount = rightTo - rightFrom + 1;
        }

        if(m.captures["oper"] == "a")
        {
            leftFrom++;
            leftCount--;
        }
        else if(m.captures["oper"] == "d")
        {
            rightFrom++;
            rightCount--;
        }

        Diff d = Diff(0, 0, 0);
        d.nofEquals = leftFrom - currentLine1;
        assertEqual(d.nofEquals, rightFrom - currentLine2);
        d.diff1 = leftCount;
        d.diff2 = rightCount;

        currentLine1 += d.nofEquals + d.diff1;
        currentLine2 += d.nofEquals + d.diff2;

        return d;
    }

    unittest
    {
        Diff d;
        int line1, line2;

        // a | b
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("1c1", line1, line2);
        assertEqual(d, Diff(0, 1, 1));
        assertEqual(line1, 1);
        assertEqual(line2, 1);

        // a | b
        //   | b
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("1c1,2", line1, line2);
        assertEqual(d, Diff(0, 1, 2));
        assertEqual(line1, 1);
        assertEqual(line2, 2);

        // a | b
        // a |
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("1,2c1", line1, line2);
        assertEqual(d, Diff(0, 2, 1));
        assertEqual(line1, 2);
        assertEqual(line2, 1);

        // a | a
        //   | b
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("1a2", line1, line2);
        assertEqual(d, Diff(1, 0, 1));
        assertEqual(line1, 1);
        assertEqual(line2, 2);

        // a | a
        // b |
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("2d1", line1, line2);
        assertEqual(d, Diff(1, 1, 0));
        assertEqual(line1, 2);
        assertEqual(line2, 1);

        //   | b
        //   | b
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("0a1,2", line1, line2);
        assertEqual(d, Diff(0, 0, 2));
        assertEqual(line1, 0);
        assertEqual(line2, 2);

        // b |
        // b |
        line1 = 0;
        line2 = 0;
        d = gnudiffhunk_2_diff("1,2d0", line1, line2);
        assertEqual(d, Diff(0, 2, 0));
        assertEqual(line1, 2);
        assertEqual(line2, 0);
    }

    private static DiffList gnudiff_2_difflist(string difflines, int size1, int size2)
    {
        int currentLine1 = 0;
        int currentLine2 = 0;
        DiffList diffList;

        foreach(line; difflines.splitLines())
        {
            auto diff = gnudiffhunk_2_diff(line, currentLine1, currentLine2);
            diffList.insertBack(diff);
        }

        int remainingLines1 = size1 - currentLine1;
        int remainingLines2 = size2 - currentLine2;
        assertEqual(remainingLines1, remainingLines2, "Remaining lines not the same for the two files");
        if(remainingLines1 > 0)
        {
            diffList.insertBack(Diff(remainingLines1, 0, 0));
        }

        verifyDiffList(diffList, size1, size2);

        return diffList;
    }

    unittest
    {
        DiffList dl;

        /* Test equal files */
        dl = gnudiff_2_difflist("", 3, 3);
        assertEqual(array(dl[]), [Diff(3, 0, 0)]);

        /* Test entirely different files */
        dl = gnudiff_2_difflist("1,3c1,5", 3, 5);
        assertEqual(array(dl[]), [Diff(0, 3, 5)]);

        /* Test an insertion in the middle of the file */
        dl = gnudiff_2_difflist("8,11d7", 15, 11);
        assertEqual(array(dl[]), [Diff(7, 4, 0),
                                  Diff(4, 0, 0)]);

        /* Test a change in the middle of the file */
        dl = gnudiff_2_difflist("2,3c2,5", 4, 6);
        assertEqual(array(dl[]), [Diff(1, 2, 4),
                                  Diff(1, 0, 0)]);

        /* Test a change at the start of the file */
        dl = gnudiff_2_difflist("1,3c1,5", 4, 6);
        assertEqual(array(dl[]), [Diff(0, 3, 5),
                                  Diff(1, 0, 0)]);


    }

    private static void verifyDiffList(DiffList diffList, int size1, int size2)
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

    private string diff_2_files(uint n1, uint n2,
                                int firstLine1, int lastLine1,
                                int firstLine2, int lastLine2)
    {
        auto fifoName1 = getFifoName(n1);
        auto fifoName2 = getFifoName(n2);
        recreateFifo(fifoName1);
        recreateFifo(fifoName2);

        auto diff = pipeShell(format("diff %s %s | grep -v '^[<>-]'", fifoName1, fifoName2), Redirect.stdout);

        auto inputFifo1 = open(fifoName1.toStringz, O_WRONLY);
        fcntl(inputFifo1, F_SETFL, O_NONBLOCK);

        auto inputFifo2 = open(fifoName2.toStringz, O_WRONLY);
        fcntl(inputFifo2, F_SETFL, O_NONBLOCK);

        auto outputFifo = diff.stdout.fileno;

        pollfd[3] pollFifos = [ { fd: inputFifo1, events: POLLOUT },
                                { fd: inputFifo2, events: POLLOUT },
                                { fd: outputFifo, events: POLLIN  } ];
        FifoWriter[] writers = [ new FifoWriter(m_lineProviders[n1], inputFifo1),
                                 new FifoWriter(m_lineProviders[n2], inputFifo2) ];
        FifoReader reader = new FifoReader(outputFifo);

        bool done = false;
        while(!writers[0].eof() ||
              !writers[1].eof() ||
              !reader.eof() )
        {
            poll(&pollFifos[0], 3, -1);

            foreach(i; 0..2)
            {
                if(pollFifos[i].revents)
                {
                    writers[i].write();
                    if(writers[i].eof())
                    {
                        close(pollFifos[i].fd);
                        pollFifos[i].fd = -1;
                    }
                }
            }

            if(pollFifos[2].revents)
            {
                reader.read();
            }
        }

        assert(writers[0].eof() && writers[1].eof());

        auto status = wait(diff.pid);
        enforce(status != 2, "Diff failed");

        return reader.getText();
    }

    private void recreateFifo(string pathToFifo)
    {
        if(std.file.exists(pathToFifo))
        {
            removeFifo(pathToFifo);
        }
        createFifo(pathToFifo);
    }
    private void createFifo(string pathToFifo)
    {
        auto mkfifo = execute(["mkfifo", "-m", "0600", pathToFifo]);
        enforce(mkfifo.status == 0, format("mkfifo failed for %s with message: %s", pathToFifo, mkfifo.output));
    }

    private void removeFifo(string pathToFifo)
    {
        std.file.remove(pathToFifo);
    }
}

