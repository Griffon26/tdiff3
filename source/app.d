import core.thread;
import std.container;
import std.stdio;

import diff;
import fifowriter;
import gnudiff;
import simplefilelineprovider;

void dingesfunc(DList!int d)
{
    foreach(elem; d)
    {
        writefln("inner el %s", elem);
    }
}

void main()
{
    const int count = 3;

    shared(SimpleFileLineProvider) lps[count];
    lps[0] = new shared SimpleFileLineProvider("testdata/test.txt");
    lps[1] = new shared SimpleFileLineProvider("testdata/test.txt");
    lps[2] = new shared SimpleFileLineProvider("testdata/test.txt");

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

    auto diffList12 = gnuDiff.runDiff(0, 1, 0, -1, 0, -1);
    auto diffList23 = gnuDiff.runDiff(1, 2, 0, -1, 0, -1);
    auto diffList13 = gnuDiff.runDiff(0, 2, 0, -1, 0, -1);

    auto diff3LineList = diff.calcDiff3LineList(diffList12, diffList23, diffList13);

    writefln("Cleaning up");

    gnuDiff.cleanup();

    writefln("Exiting main");

    DList!int dinges;
    dinges.insertBack(3);
    dinges.insertBack(4);
    dinges.insertBack(5);
    dingesfunc(dinges);
    foreach(el; dinges)
    {
        writefln("element %d", el);
    }
}

