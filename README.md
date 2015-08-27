# tdiff3
A text-based 3-way diff/merge tool that can handle large files

This program is based on the merge algorithm of kdiff3, but was written from scratch in D (http://dlang.org) and released under the GPL.

The differences with kdiff3 (and possibly other diff/merge programs) are:
* it runs in a terminal (no dependency on X or Qt)
* it was designed to handle very large files efficiently, both in terms of speed as well as in the amount of memory it uses

## Project status

Tdiff3 is still at an early stage of development. This means that some shortcuts were taken to quickly get the application into a usable state. Some examples:
* for now the input files are read entirely into memory when the application starts
* no editing of the merge result is possible yet, only conflict resolution through selection

This will be the focus of development in the coming period, along with important usability improvements.

If you're interested in this program, either as a user or possibly even a developer I'd love to hear from you. You can find my email address on GitHub.

## Screenshots

![A screenshot of an xterm with tdiff3 running](/docs/images/screenshot1.png?raw=true)

## Requires
* ncurses >= 5.9
* libtermkey >= 0.17

## Compiling from source

1. Install libtermkey (preferably using your distribution's package manager, but alternatively following the steps below)
2. Install the [DMD compiler](http://dlang.org/dmd-linux.html)
3. Install [DUB - The D package repository](http://code.dlang.org/getting_started)
4. Get, build and run tdiff3

This can be as simple as:

    1.
        (Skip this step if you have installed libtermkey using your package manager)
        cd ~/somedir
        wget http://www.leonerd.org.uk/code/libtermkey/libtermkey-0.17.tar.gz
        tar zxf libtermkey-0.17.tar.gz
        (cd libtermkey-0.17; make install PREFIX=${HOME}/somedir/local-libtermkey)
        export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOME}/somedir/local-libtermkey/lib
        export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:${HOME}/somedir/local-libtermkey/lib/pkgconfig
        
    2.  
        cd ~/somedir
        wget http://downloads.dlang.org/releases/2.x/2.068.0/dmd.2.068.0.linux.zip
        unzip dmd.2.068.0.linux.zip
        export PATH=${PATH}:${HOME}/somedir/dmd2/linux/bin64
        
    3.  git clone --branch v0.9.24-rc.3 https://github.com/D-Programming-Language/dub.git
        (cd dub; ./build.sh)  # don't leave out the parentheses
        export PATH=${PATH}:${HOME}/somedir/dub/bin
        
    4.  git clone https://github.com/Griffon26/tdiff3.git
        cd tdiff3 && dub
        ./tdiff3
