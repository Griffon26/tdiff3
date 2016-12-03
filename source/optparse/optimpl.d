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
/*
2007-08-15 - Added changes to make GDC happy, submitted by Tim Burrell.
*/
/**
 * Command-line option parsing, in the style of Python's optparse.
 *
 * Refer to the complete docs for more information.
 */
module optimpl;

import core.stdc.stdlib : exit, EXIT_FAILURE, EXIT_SUCCESS;
import std.string : indexOf, toUpper;
import std.conv : to, ConvException;
import std.path : baseName;
import std.utf : toUTF8, toUTF32;

/*
Options may be in two forms: long and short. Short options start with a single
dash and are one letter long. Long options start with two dashes and may
consist of any number of characters (so long as they don't start with a dash,
though they may contain dashes). Options are case-sensitive.

Short options may be combined. The following are equivalent:

$ myapp -a -b -c
$ myapp -abc
$ myapp -ab -c

If -f and --file are aliases of the same option, which accepts an argument,
the following are equivalent:

$ myapp -f somefile.txt
$ myapp -fsomefile.txt
$ myapp --file somefile.txt
$ myapp --file=somefile.txt

The following are also valid:

$ myapp -abcf somefile.txt
$ myapp -abcfsomefile.txt
$ myapp -abc --file somefile.txt

If an option occurs multiple times, the last one is the one recorded:

$ myapp -f somefile.txt --file otherfile.txt

Matches 'otherfile.txt'.
*/

bool startswith(string s, string start) {
    if (s.length < start.length) return false;
    return s[0 .. start.length] == start;
}
bool endswith(string s, string end) {
    if (s.length < end.length) return false;
    return s[$ - end.length .. $] == end;
}

/// Thrown if client code tries to set up an improper option.
class OptionError : Exception {
    this(string msg) { super(msg); }
}
/// Thrown if client code tries to extract the wrong type from an option.
class OptionTypeError : Exception {
    this(string msg) { super(msg); }
}
/// Thrown if there is a problem while parsing the command-line.
class OptionParsingError : Exception {
    this(string msg) { super(msg); }
}

/++
This class represents the results after parsing the command-line.
+/
class Options {
    string[][string] opts;
    int[string] counted_opts;
    /// By default, leftover arguments are placed in this array.
    string[] args;

    /// Retrieves the results of the Store and StoreConst actions.
    string opIndex(string opt) {
        string[]* o = opt in opts;
        if (o) {
            return (*o)[0];
        } else {
            return "";
        }
    }
    /// Retrieves the results of the Store action, when the type is Integer.
    int value(string opt) {
        string[]* o = opt in opts;
        if (o) {
            return to!int((*o)[0]);
        } else {
            return 0;
        }
    }
    /// Retrieves the results of the Append and AppendConst actions.
    string[] list(string opt) {
        string[]* o = opt in opts;
        if (o) {
            return *o;
        } else {
            return null;
        }
    }
    /// Retrieves the results of the Append action, when the type is Integer.
    int[] valueList(string opt) {
        string[]* o = opt in opts;
        int[] l;
        if (o) {
            l.length = (*o).length;
            foreach (i, s; *o) {
                l[i] = to!int(s);
            }
        }
        return l;
    }
    /// Retrieves the results of the Count action.
    int count(string opt) {
        int* c = opt in counted_opts;
        if (c) {
            return *c;
        } else {
            return 0;
        }
    }
    /// Retrieves the results of the SetTrue and SetFalse actions.
    bool flag(string opt) {
        string[]* o = opt in opts;
        if (o) {
            return (*o)[0] == "1";
        } else {
            return false;
        }
    }
    private {
        void storeArg(string name, string arg) {
            opts[name] = [arg];
        }
        void storeArg(string name, bool arg) {
            if (arg) {
                opts[name] = ["1"];
            } else {
                opts[name] = ["0"];
            }
        }
        void appendArg(string name, string arg) {
            opts[name] ~= arg;
        }
        void increment(string name) {
            ++counted_opts[name];
        }
        bool hasName(string name) {
            return name in opts || name in counted_opts;
        }
    }
}

// Options, args, this opt's index in args, name[, arg]
///
alias void delegate(Options, inout string[], inout ulong, string, string) OptionCallbackFancyArg;
///
alias void delegate(Options, inout string[], inout ulong, string, int)    OptionCallbackFancyInt;
///
alias void delegate(Options, inout string[], inout ulong, string)         OptionCallbackFancy;

///
alias void delegate(string) OptionCallbackArg;
///
alias void delegate(int)    OptionCallbackInt;
///
alias void delegate()       OptionCallback;

///
enum Action { /+++/Store, /+++/StoreConst, /+++/Append, /+++/AppendConst, /+++/Count, /+++/SetTrue, /+++/SetFalse, /+++/Callback, /+++/CallbackFancy, /+++/Help /+++/}
///
enum ArgType { /+/+++/None,+/ /+++/String, /+++/Integer, /+++/Bool /+++/}

/++
This class represents a single command-line option.
+/
abstract class Option {
    string[] shortopts, longopts;
    string name, argname;
    string helptext;
    this(string[] options, string name) {
        dstring opt;
        foreach (_opt; options) {
            // (Unicode note: We convert to dstring so the length checks work
            // out in the event of a short opt with a >127 character.)
            opt = toUTF32(_opt);
            if (opt.length < 2) {
                throw new OptionError(
                    "invalid option string '" ~ _opt ~ "': must be at least two characters long"
                );
            } else if (opt.length > 2) {
                if (opt[0 .. 2] != "--" || opt[2] == '-')
                    throw new OptionError(
                        "invalid long option string '" ~ _opt ~ "': must start with --, followed by non-dash"
                    );
                longopts ~= _opt;
            } else {
                if (opt[0] != '-' || opt[1] == '-')
                    throw new OptionError(
                        "invalid short option string '" ~ _opt ~ "': must be of the form -x, where x is non-dash"
                    );
                shortopts ~= _opt;
            }
        }
        if (name is null) {
            // (Unicode note: We know '-' is a single code unit, so these
            // slices are okay.)
            if (longopts.length > 0)
                this.name = longopts[0][2 .. $];
            else if (shortopts.length > 0)
                this.name = shortopts[0][1 .. 2];
            else
                throw new OptionError(
                    "No options provided to addOption!"
                );
        } else {
            this.name = name;
        }
        // TODO: remove dup?
        argname = toUpper(this.name.dup);
    }
    override string toString() {
        ulong optCount = this.shortopts.length + this.longopts.length;
        string result;
        //bool printed_arg = false;
        foreach(i, opt; this.shortopts ~ this.longopts) {
            result ~= opt;
            if (i < optCount-1) {
                result ~= ", ";
            } else if (this.hasArg()) {
                // TODO: remove dup?
                result ~= "=" ~ toUpper(this.argname.dup);
            }
        }
        return result;
    }
    //enum Action { Store, StoreConst, Append, AppendConst, Count, SetTrue, SetFalse, Callback, CallbackFancy, Help }
    bool supports_default() {
        return false;
    }
    ArgType def_type() {
        throw new OptionError("Option "~name~" does not support default arguments.");
    }
    bool has_default() {
        throw new OptionError("Option "~name~" does not support default arguments.");
    }
    void issue_default(Options results) {
        return;
    }
    /// Does whatever this option is supposed to do.
    abstract void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg);
    /// Returns whether this option accepts an argument.
    bool hasArg() {
        return false;
    }
    /// Sets the help text for this option.
    Option help(string help) {
        this.helptext = help;
        return this;
    }
    /// Sets the name of this option's argument, if it has one.
    Option argName(string argname) {
        this.argname = argname;
        return this;
    }
    Option def(string val) {
        throw new OptionError("Cannot specify string default for non-string option '"~this.name~"'");
    }
    Option def(int val) {
        throw new OptionError("Cannot specify integer default for non-integer option '"~this.name~"'");
    }
    Option def(bool val) {
        throw new OptionError("Cannot specify boolean default for non-flag option '"~this.name~"'");
    }
    // Returns true if the passed option string matches this option.
    bool matches(string _arg) {
        dstring arg = toUTF32(_arg);
        if (
            arg.length < 2 ||
            arg.length == 2 && (arg[0] != '-' || arg[1] == '-') ||
            arg.length > 2 && (arg[0 .. 2] != "--" || arg[2] == '-')
        ) {
            return false;
        }
        if (arg.length == 2) {
            foreach (opt; shortopts) {
                if (_arg == opt) {
                    return true;
                }
            }
        } else {
            foreach (opt; longopts) {
                if (_arg == opt) {
                    return true;
                }
            }
        }
        return false;
    }
}

abstract class ArgOption : Option {
    static const ArgType default_type = ArgType.String;
    ArgType type;
    bool _has_default = false;
    string default_string;
    this(string[] options, string name, ArgType type) {
        super(options, name);
        if (type != ArgType.Integer && type != ArgType.String) {
            throw new OptionError("Argument type for Store and Append must be Integer or String.");
        }
        this.type = type;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        if (this.type == ArgType.Integer) {
            // Verify that it's an int.
            int i = parser.toOptInt(arg);
        }
    }
    override ArgType def_type() {
        return this.type;
    }
    alias def = Option.def;
    override Option def(string val) {
        if (this.type != ArgType.String)
            super.def(val);
        this._has_default = true;
        this.default_string = val;
        return this;
    }
    override Option def(int val) {
        if (this.type != ArgType.Integer)
            super.def(val);
        this._has_default = true;
        this.default_string = to!string(val);
        return this;
    }
    override bool supports_default() {
        return true;
    }
    override bool has_default() {
        return _has_default;
    }
    override void issue_default(Options results) {
        if (_has_default) results.storeArg(this.name, this.default_string);
    }
    override bool hasArg() {
        return true;
    }
}

class Store : ArgOption {
    this(string[] options, string name, ArgType type=Store.default_type) {
        super(options, name, type);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        super.performAction(parser, results, args, idx, arg);
        results.storeArg(this.name, arg);
    }
}
class Append : ArgOption {
    this(string[] options, string name, ArgType type=Append.default_type) {
        super(options, name, type);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        super.performAction(parser, results, args, idx, arg);
        results.appendArg(this.name, arg);
    }
}
abstract class ConstOption : Option {
    bool _has_default = false;
    string default_value;
    string const_value;
    this(string[] options, string name, string const_value) {
        super(options, name);
        this.const_value = const_value;
    }
    alias def = Option.def;
    override Option def(string val) {
        this._has_default = true;
        this.default_value = val;
        return this;
    }
    override ArgType def_type() {
        return ArgType.String;
    }
    override bool supports_default() {
        return true;
    }
    override bool has_default() {
        return _has_default;
    }
    override void issue_default(Options results) {
        if (_has_default) results.storeArg(this.name, this.default_value);
    }
}
class StoreConst : ConstOption {
    this(string[] options, string name, string const_value) {
        super(options, name, const_value);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        results.storeArg(this.name, this.const_value);
    }
}
class AppendConst : ConstOption {
    this(string[] options, string name, string const_value) {
        super(options, name, const_value);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        results.appendArg(this.name, this.const_value);
    }
}
abstract class SetBool : Option {
    bool _has_default = false;
    bool default_flag = false;
    this(string[] options, string name) {
        super(options, name);
    }
    alias def = Option.def;
    override Option def(bool val) {
        this._has_default = true;
        this.default_flag = val;
        return this;
    }
    override ArgType def_type() {
        return ArgType.Bool;
    }
    override bool supports_default() {
        return true;
    }
    override bool has_default() {
        return _has_default;
    }
    override void issue_default(Options results) {
        if (_has_default) results.storeArg(this.name, this.default_flag);
    }
}
class SetTrue : SetBool {
    this(string[] options, string name) {
        super(options, name);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        results.storeArg(this.name, true);
    }
}
class SetFalse : SetBool {
    this(string[] options, string name) {
        super(options, name);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        results.storeArg(this.name, false);
    }
}
class Count : Option {
    this(string[] options, string name) {
        super(options, name);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        results.increment(this.name);
    }
}
class Callback : Option {
    OptionCallback cb;
    this(string[] options, OptionCallback cb) {
        super(options, null);
        this.cb = cb;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        this.cb();
    }
}
class CallbackArg : Option {
    OptionCallbackArg cb;
    this(string[] options, OptionCallbackArg cb) {
        super(options, null);
        this.cb = cb;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        this.cb(arg);
    }
    override bool hasArg() {
        return true;
    }
}
class CallbackInt : Option {
    OptionCallbackInt cb;
    this(string[] options, OptionCallbackInt cb) {
        super(options, null);
        this.cb = cb;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        int i = parser.toOptInt(arg);
        this.cb(i);
    }
    override bool hasArg() {
        return true;
    }
}
class FancyCallback : Option {
    OptionCallbackFancy cb;
    this(string[] options, string name, OptionCallbackFancy cb) {
        super(options, name);
        this.cb = cb;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        this.cb(results, args, idx, this.name);
    }
}
class FancyCallbackArg : Option {
    OptionCallbackFancyArg cb;
    this(string[] options, string name, OptionCallbackFancyArg cb) {
        super(options, name);
        this.cb = cb;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        this.cb(results, args, idx, this.name, arg);
    }
    override bool hasArg() {
        return true;
    }
}
class FancyCallbackInt : Option {
    OptionCallbackFancyInt cb;
    this(string[] options, string name, OptionCallbackFancyInt cb) {
        super(options, name);
        this.cb = cb;
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        int i = parser.toOptInt(arg);
        this.cb(results, args, idx, this.name, i);
    }
    override bool hasArg() {
        return true;
    }
}
class Help : Option {
    this(string[] options) {
        super(options, null);
    }
    override void performAction(OptionParser parser, Options results, inout string[] args, inout ulong idx, string arg) {
        parser.helpText();
        exit(EXIT_SUCCESS);
    }
}

/++
This class is used to define a set of options, and parse the command-line
arguments.
+/
class OptionParser {
    OptionCallbackArg leftover_cb;
    /// An array of all of the options known by this parser.
    Option[] options;
    string name, desc;
    /// The description of the programs arguments, as used in the Help action.
    string argdesc;
    private void delegate(string) error_callback;

    this(string desc="".dup) {
        this.name = "";
        this.desc = desc;
        this.argdesc = "[options] args...";
    }

    /// Sets a callback, to override the default error behavior.
    void setErrorCallback(void delegate(string) dg) {
        error_callback = dg;
    }
    void unknownOptError(string opt) {
        error("Unknown argument '"~opt~"'");
    }
    void expectedArgError(string opt) {
        error("'"~opt~"' option expects an argument.");
    }
    /// Displays an error message and terminates the program.
    void error(string err) {
        if (error_callback !is null) {
            error_callback(err);
        } else {
            this.helpText();
        }
        throw new OptionParsingError(err);
    }
    version (Tango) {
        int toOptInt(string s) {
            uint ate;
            int i = cast(int)(.parse(s, 10u, &ate));
            if (ate != s.length)
                error("Could not convert '"~s~"' to an integer.");
            return i;
        }
    } else {
        int toOptInt(string s) {
            int i;
            try {
                i = to!int(s);
            } catch (ConvException e) {
                error("Could not convert '"~s~"' to an integer.");
            }
            return i;
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
    string[][] helpText() {
        string[][] ret;
        foreach(i, opt; options) {
            ret ~= [opt.toString(), opt.helptext];
        }
        return ret;
    }
    
    // Checks the passed arg against all the options in the parser.
    // Returns null if no match is found.
    Option matches(string arg) {
        foreach(o; options) {
            if (o.matches(arg)) {
                return o;
            }
        }
        return null;
    }
    version (Tango) {
        string getProgramName(string path) {
            version(Windows) {
                char delimiter = '\\';
            } else {
                char delimiter = '/';
            }
            uint idx = locatePrior(path, delimiter);
            if (idx == path.length) return path;
            return path[idx+1 .. $];
        }
    } else {
        string getProgramName(string path) {
            version(Windows) {
                // (Unicode note: ".exe" only contains 4 code units, so this slice
                // should Just Work.) (Although it remains to be seen how robust
                // this code actually is.)
                assert(path[$-4 .. $] == ".exe");
                path = path[0 .. $-4];
            }
            return baseName(path);
        }
    }
    /// Parses the passed command-line arguments and returns the results.
    Options parse(string[] args) {
        this.name = getProgramName(args[0]);
        args = args[1 .. $];
        Options options = new Options;
        /*
        The issue is this:

        $ myapp -abc

        This might be three short opts, or one or two opts, the last of which
        accepts an argument. In the three-opt case, we want to get:

        $ myapp -a -b -c

        In the one-opt case, we want:

        $ myapp -a bc

        In the two-opt case, we want:

        $ myapp -a -b c

        We also want to parse apart "--file=somefile" into "--file somefile"
        */
        string opt, newopt, arg;
        dstring opt32;
        ptrdiff_t idx;
        Option match;

        foreach (o; this.options) {
            o.issue_default(options);
        }

        for (size_t i=0; i<args.length; ++i) {
            opt = args[i];
            // -- ends the option list, the remainder is dumped into args
            if (opt == "--") {
                if (this.leftover_cb !is null) {
                    foreach(a; args[i+1 .. $]) {
                        this.leftover_cb(a);
                    }
                } else {
                    options.args ~= args[i+1 .. $];
                }
                i = args.length;
            } else if (opt.startswith("--")) {
                idx = indexOf(opt, '=');
                if (idx != -1) {
                    newopt = opt[0 .. idx];
                    // Stitch out the old arg, stitch in the newopt, arg pair.
                    // (Unicode note: idx+1 works, since we know '=' is a
                    // single code unit.)
                    args = args[0 .. i] ~ [newopt, opt[idx+1 .. $]] ~ args[i+1 .. $];
                } else {
                    newopt = opt;
                }
                match = matches(newopt);
                if (match is null) {
                    unknownOptError(newopt);
                }
                if (match.hasArg) {
                    if (i == args.length-1) expectedArgError(match.name);
                    arg = args[i+1];
                    ++i;
                } else {
                    arg = null;
                }
                match.performAction(this, options, args, i, arg);
            } else if (opt.startswith("-")) {
                if (opt.length >= 2) {
                    opt32 = toUTF32(opt[1 .. $]);
                    foreach (j, c; opt32) {
                        newopt = toUTF8("-" ~ [c]);
                        match = matches(newopt);
                        if (match is null) {
                            unknownOptError(newopt);
                        }
                        if (match.hasArg) {
                            // This is the last char in the group, look to the
                            // next element of args for the arg.
                            if (j == opt32.length-1) {
                                if (i == args.length-1) expectedArgError(match.name);
                                arg = args[i+1];
                                ++i;
                            // Otherwise, consume the rest of this group for
                            // the arg.
                            } else {
                                arg = toUTF8(opt32[j+1 .. $]);
                                match.performAction(this, options, args, i, arg);
                                break;
                            }
                        } else {
                            arg = null;
                        }
                        match.performAction(this, options, args, i, arg);
                    }
                } else {
                    unknownOptError(opt);
                }
            } else {
                if (this.leftover_cb is null) {
                    options.args ~= opt;
                } else {
                    this.leftover_cb(opt);
                }
            }
        }
        return options;
    }

    /++
    Overrides the default behavior of leftover arguments, calling this callback
    with them instead of adding them an array.
    +/
    void leftoverCallback(OptionCallbackArg dg) {
        this.leftover_cb = dg;
    }
    private void wrong_args(string[] options) {
        if (options.length > 0) {
            throw new OptionError(
                "Wrong arguments to addOption for option '"
                ~options[0]~"'."
            );
        } else {
            throw new OptionError("Found an empty option!");
        }
    }
    ///
    Option addOption(string[] options ...) {
        return addOption(new Store(options, null));
    }
    ///
    Option addOption(string[] options, string name) {
        return addOption(new Store(options, name));
    }
    ///
    Option addOption(string[] options, Action action) {
        Option o;
        switch (action) {
            case Action.Store, Action.Append:
                return addOption(options, null, action, ArgOption.default_type);
            case Action.Count:
                return addOption(options, null, action);
            case Action.Help:
                return addOption(new Help(options));
            default:
                wrong_args(options);
                break;
        }
        return addOption(o);
    }
    ///
    Option addOption(string[] options, ArgType type) {
        return addOption(new Store(options, null, type));
    }
    ///
    Option addOption(string[] options, Action action, ArgType type) {
        return addOption(options, null, action, type);
    }
    ///
    Option addOption(string[] options, string name, Action action) {
        Option o;
        switch (action) {
            case Action.Store, Action.Append:
                return addOption(options, name, action, ArgOption.default_type);
            case Action.Count:
                o = new Count(options, name);
                break;
            case Action.SetTrue:
                o = new SetTrue(options, name);
                break;
            case Action.SetFalse:
                o = new SetFalse(options, name);
                break;
            default:
                wrong_args(options);
                break;
        }
        return addOption(o);
    }
    ///
    Option addOption(string[] options, string name, Action action, ArgType type) {
        Option o;
        switch (action) {
            case Action.Store:
                o = new Store(options, name, type);
                break;
            case Action.Append:
                o = new Append(options, name, type);
                break;
            default:
                wrong_args(options);
                break;
        }
        return addOption(o);
    }
    ///
    Option addOption(string[] options, Action action, string const_value) {
        return addOption(options, null, action, const_value);
    }
    ///
    Option addOption(string[] options, string name, string const_value) {
        return addOption(options, name, Action.StoreConst, const_value);
    }
    ///
    Option addOption(string[] options, string name, Action action, string const_value) {
        Option o;
        switch (action) {
            case Action.StoreConst:
                o = new StoreConst(options, name, const_value);
                break;
            case Action.AppendConst:
                o = new AppendConst(options, name, const_value);
                break;
            default:
                wrong_args(options);
                break;
        }
        return addOption(o);
    }
    ///
    Option addOption(string[] options, OptionCallback dg) {
        return addOption(new Callback(options, dg));
    }
    ///
    Option addOption(string[] options, OptionCallbackArg dg) {
        return addOption(new CallbackArg(options, dg));
    }
    ///
    Option addOption(string[] options, OptionCallbackInt dg) {
        return addOption(new CallbackInt(options, dg));
    }
    ///
    Option addOption(string[] options, OptionCallbackFancy dg) {
        return addOption(new FancyCallback(options, null, dg));
    }
    ///
    Option addOption(string[] options, OptionCallbackFancyArg dg) {
        return addOption(new FancyCallbackArg(options, null, dg));
    }
    ///
    Option addOption(string[] options, OptionCallbackFancyInt dg) {
        return addOption(new FancyCallbackInt(options, null, dg));
    }
    ///
    Option addOption(string[] options, string name, OptionCallbackFancy dg) {
        return addOption(new FancyCallback(options, name, dg));
    }
    ///
    Option addOption(string[] options, string name, OptionCallbackFancyArg dg) {
        return addOption(new FancyCallbackArg(options, name, dg));
    }
    ///
    Option addOption(string[] options, string name, OptionCallbackFancyInt dg) {
        return addOption(new FancyCallbackInt(options, name, dg));
    }
    // Although users certainly /can/ call this, all those overloads are there
    // for a reason.
    Option addOption(Option option) {
        this.options ~= option;
        return option;
    }
}

