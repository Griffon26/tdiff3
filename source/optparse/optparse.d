/*
Copyright (c) 2007 Kirk McDonald

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
/**
 * Command-line option parsing, in the style of Python's optparse.
 *
 * This is the command-line interface to optparse.
 */
module optparse;

import optimpl;
public import optimpl : Options, Option, Action, ArgType,
    OptionCallbackFancy,
    OptionCallbackFancyArg,
    OptionCallbackFancyInt,
    OptionCallback,
    OptionCallbackArg,
    OptionCallbackInt,
    OptionParsingError;

version (Tango) {
    import tango.io.Stdout : Stdout;
    import tango.stdc.stdlib : exit, EXIT_FAILURE, EXIT_SUCCESS;
    /+
    import tango.text.Util : find = locate, locatePrior;
    import tango.text.Ascii : toupper = toUpper;
    import tango.text.convert.Integer : parse, toInt, toString = toUtf8;
    import tango.text.convert.Utf : toUTF8 = toUtf8, toUTF32 = toUtf32;
    int getNotFound(string s) {
        return s.length;
    }
    //alias string string;
    +/
} else {
    import std.stdio : writefln, writef;
    import std.c.stdlib : exit, EXIT_FAILURE, EXIT_SUCCESS;
    /+
    import std.string : find, toupper, toString;
    import std.conv : toInt, ConvError;
    import std.path : getBaseName;
    import std.utf : toUTF8, toUTF32;
    int getNotFound(string s) {
        return -1;
    }
    +/
}

/++
This class is used to define a set of options, and parse the command-line
arguments.
+/
class OptionParser : optimpl.OptionParser {
    this(string desc="") {
        super(desc);
    }
    /// Displays an error message and terminates the program.
    override void error(string err) {
        try {
            super.error(err);
        } catch(OptionParsingError e) {
            version (Tango) {
                Stdout.formatln("{0}", e);
            } else {
                writefln(e.msg);
            }
            exit(EXIT_FAILURE);
        }
    }
    /+
    Returns an array of arrays of strings with  useful "help" information about the program's
    options.

    The array looks something like this:
    [
        ['option', 'help text'],
        ['option', 'help text'],
        ...
    ]
    +/
    override string[][] helpText() {
        ulong optWidth = 0;
        string[][] help = super.helpText();
        // Calculate the maximum width of the option lists.
        foreach(i, opt; help) {
            if (opt[0].length > optWidth) {
                optWidth = opt[0].length;
            }
        }
        version (Tango) {
            alias spacechar = Typedef!(char, ' ');
            spacestring padding;
            Stdout.formatln("Usage: {0} {1}", this.name, this.argdesc);
            if (this.desc !is null && this.desc != "") Stdout(this.desc).newline;
            Stdout("\nOptions:").newline;
            foreach(i, opt; help) {
                padding.length = optWidth - opt[0].length;
                Stdout.formatln("  {0}{1} {2}", opt[0], cast(string)padding, opt[1]);
            }
        } else {
            writefln("Usage: %s %s", this.name, this.argdesc);
            if (this.desc !is null && this.desc != "") writefln(this.desc);
            writefln("\nOptions:");
            foreach(i, opt; help) {
                // The commented-out code is a great idea I'll do properly later.
                //if (opt.helptext.length + optWidth + 3 > 80) {
                //    writefln("  %s\n\t%s", optStrs[i], opt.helptext);
                //} else {
                writefln("  %-*s %s", optWidth, opt[0], opt[1]);
                //}
            }
        }
        return help;
    }
}

