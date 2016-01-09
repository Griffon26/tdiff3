GNU diffutils source code
=========================

The gnudiff directory contains a subset of the code from GNU diffutils.

The files in `src/` have been modified to compile in isolation by commenting out
unnecessary parts, mostly using `#if 0 .. #endif`. This should make it easy to
identify the changes made to the original sources and to apply these changes to
later versions of the same sources.

The files in `stub/` have been added to replace unwanted dependencies and, in the
case of `normal.c`, to replace printing of differences with a call to a callback
function that is set from the main program.

Please update version information below when a different version of the sources
is included.

Version info
------------

```
git         : http://git.savannah.gnu.org/cgit/diffutils.git
tag         : v2.8.7
commit      : 4a1de90b3c191e6854a5f91360b50d5f9ef8e89
description : This is the latest version of diffutils still released under 
              GPLv2 and I was not ready to switch to GPLv3 for Tdiff3.
```