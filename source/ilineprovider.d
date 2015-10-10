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
module ilineprovider;

import std.typecons;

/**
 * ILineProvider provides line-based access to input data.
 * Originally the plan was to have a chain of ILineProviders that could apply
 * filtering to data read from the input files (decoding/encoding, line
 * preprocessing, ...).
 * ILineProvider was originally synchronized. Now that the synchronized keyword
 * has been removed, maybe this interface can be replaced by IContentProvider.
 */
interface ILineProvider
{
    Tuple!(int, "count", string, "text") get(int line);
    Tuple!(int, "count", string, "text") get(int firstLine, int lastLine);
    int getLastLineNumber();
}

version(unittest)
{
    import std.string;

    class FakeLineProvider: ILineProvider
    {
        override Tuple!(int, "count", string, "text") get(int line)
        {
            return tuple!("count", "text")(1, format("line %d\n", line));
        }

        override Tuple!(int, "count", string, "text") get(int firstLine, int lastLine)
        {
            return tuple!("count", "text")(0, "");
        }

        int getLastLineNumber()
        {
            return 19;
        }
    }
}

