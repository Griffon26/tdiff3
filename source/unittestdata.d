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
module unittestdata;

version(unittest)
{
    string one_byte_one_column = "a";
    //dchar one_byte_two_columns = '';

    string two_bytes_zero_columns = "\u0301"; // Unicode Character 'COMBINING ACUTE ACCENT' (U+0301)
    string two_bytes_one_column = "é";
    //dchar two_bytes_two_columns = '';
    string three_bytes_one_column = "€";
    string three_bytes_two_columns = "\uFF04";   // full-width dollar sign
    //dchar four_bytes_one_column = '';
    string four_bytes_two_columns = "\U00020000";    // <CJK Ideograph Extension B, First>

    // For the moment this is unprintable because glibc doesn't support it.
    string four_bytes_unprintable = "\U0001F600";    // "GRINNING FACE"
}


