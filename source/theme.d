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
module theme;

import core.stdc.config;
import std.stdio;

import common;

class Theme
{
    private c_ulong[2][DiffStyle.max + 1] m_attributes;
    private bool[DiffStyle.max + 1] m_initialized;

    void setDiffStyleAttributes(DiffStyle d, bool selected, c_ulong attr)
    {
        m_attributes[d][selected ? 1 : 0] = attr;
        m_initialized[d] = true;
    }

    c_ulong getDiffStyleAttributes(DiffStyle d, bool selected)
    {
        assert(m_initialized[d]);
        return m_attributes[d][selected ? 1 : 0];
    }
}
