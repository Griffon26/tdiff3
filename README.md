# tdiff3
A text-based 3-way diff/merge tool that can handle large files

This program is based on the merge algorithm of kdiff3, but was written from scratch in D (http://dlang.org).

The differences with kdiff3 (and possibly other diff/merge programs) are:
* it runs in a terminal (no dependency on X or Qt)
* it was designed to handle very large files efficiently, both in terms of speed as well as in the amount of memory it uses
