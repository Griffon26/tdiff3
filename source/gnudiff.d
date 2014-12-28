import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.process;
import std.regex;
import std.stdio;
import std.string;
import std.traits;

import common;
import fifowriter;
import ilineprovider;
import myassert;


const uint MAX_NR_OF_FILES = 3;

class GnuDiff
{
    private string m_tempdir;
    private FifoWriter m_fifoWriters[MAX_NR_OF_FILES];
    private shared ILineProvider m_lineProviders[MAX_NR_OF_FILES];

    this(string tempdir)
    {
        m_tempdir = tempdir;
    }

    void setFile(uint n, shared ILineProvider lp)
    {
        assert(n < MAX_NR_OF_FILES);

        m_lineProviders[n] = lp;

        auto fifoName = getFifoName(n);

        /* Attempt to remove fifos if they were left behind by a previous run of this function */
        if(std.file.exists(fifoName)) removeFifo(fifoName);

        createFifo(fifoName);
        m_fifoWriters[n] = new FifoWriter(lp, "/dev/null"); //fifoName);
    }

    void cleanup()
    {
        for(int index = 0; index < MAX_NR_OF_FILES; index++)
        {
            m_fifoWriters[index].exit();
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

        DiffList diffList = gnudiff_2_difflist(difflines,
                                               lastLine1 - firstLine1 + 1,
                                               lastLine2 - firstLine2 + 1);

        return diffList;
    }

    static DiffList gnudiff_2_difflist(string difflines, int size1, int size2)
    {
        uint currentLine1 = 0;
        uint currentLine2 = 0;
        DiffList diffList;

        foreach(line; difflines.splitLines())
        {
            auto m = match(line, regex(r"^(?P<leftFrom>\d+)(,(?P<leftTo>\d+))?[acd](?P<rightFrom>\d+)(,(?P<rightTo>\d+))?$"));
            enforce(m, format("Didn't find a match on line '%s'", line));

            /* line numbers in difflines are 1-based, so subtract 1 asap */
            int leftFrom = to!int(m.captures["leftFrom"]) - 1;
            int rightFrom = to!int(m.captures["rightFrom"]) - 1;
            int leftCount = 0;
            int rightCount = 0;

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

            if(leftCount == 0 && rightCount != 0)
            {
                leftFrom++;
            }
            else if(rightCount == 0 && leftCount != 0)
            {
                rightFrom++;
            }
            if(leftCount == 0 && rightCount == 0)
            {
                leftCount = rightCount = 1;
            }

            Diff d = Diff(0, 0, 0);
            d.nofEquals = leftFrom - currentLine1;
            assertEqual(d.nofEquals, rightFrom - currentLine2);
            d.diff1 = leftCount;
            d.diff2 = rightCount;
            currentLine1 += d.nofEquals + d.diff1;
            currentLine2 += d.nofEquals + d.diff2;
            
            diffList.insertBack(d);
        }

        int remainingLines1 = size1 - currentLine1;
        int remainingLines2 = size2 - currentLine2;
        assertEqual(remainingLines1, remainingLines2);
        diffList.insertBack(Diff(remainingLines1, 0, 0));

        verifyDiffList(diffList, size1, size2);

        return diffList;
    }

    unittest
    {
        DiffList dl;
        
        dl = gnudiff_2_difflist("", 3, 3);
        assertEqual(array(dl[]), [Diff(3, 0, 0)]);

        dl = gnudiff_2_difflist("8,11d7", 15, 11);
        assertEqual(array(dl[]), [Diff(7, 4, 0),
                                   Diff(4, 0, 0)]);
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
        m_fifoWriters[n1].start(firstLine1, lastLine1);
        m_fifoWriters[n2].start(firstLine2, lastLine2);

        //auto diff = executeShell(format("diff %s %s | grep -v '^[<>-]'", getFifoName(n1), getFifoName(n2)));
        //enforce(diff.status != 2, "Diff failed");

        m_fifoWriters[n1].wait();
        m_fifoWriters[n2].wait();

        return "";//diff.output;
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

