#pragma once

extern "C"
{

    typedef ptrdiff_t lin;

    struct file_data
    {
        lin buffered_lines;
        /* Count of lines in the prefix.
           There are this many lines in the file before linbuf[0].  */
        lin prefix_lines;

        /* Vector, indexed by line number, containing an equivalence code for
           each line.  It is this vector that is actually compared with that
           of another file to generate differences.  */
        lin *equivs;

        /* Vector, like the previous one except that
           the elements for discarded lines have been squeezed out.  */
        lin *undiscarded;

        /* Vector mapping virtual line numbers (not counting discarded lines)
           to real ones (counting those lines).  Both are origin-0.  */
        lin *realindexes;

        /* Total number of nondiscarded lines.  */
        lin nondiscarded_lines;

        /* Vector, indexed by real origin-0 line number,
           containing 1 for a line that is an insertion or a deletion.
           The results of comparison are stored here.  */
        char *changed;

        /* 1 more than the maximum equivalence value used for this or its
           sibling file.  */
        lin equiv_max;
    };

    struct comparison
    {
        file_data file[2];
    };

    int diff_2_files (comparison *);

    using HunkCallback = void (*)(int first0, int last0, int first1, int last1, void *pContext);
    void setHunkCallback(HunkCallback pHunkCallback, void *pContext);

}

