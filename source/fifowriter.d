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
module fifowriter;

import core.thread;
import std.algorithm;
import std.concurrency;
import std.stdio;

import ilineprovider;

const bool logging = false;

string MSG_DUMP_LINE_CACHE = "dumpLineCache";
string MSG_EXIT = "exit";
string MSG_DONE = "done";

struct StartMessage
{
    uint firstLine;
    uint lastLine;
}

struct DoneMessage
{
}

struct ExitMessage
{
}

/**
 * FifoWriter allows writing from an ILineProvider to a fifo from a separate
 * thread.
 */
class FifoWriter
{
    private Tid m_tid;

    this(shared ILineProvider lp, string pathToFifo)
    {
        m_tid = spawn(&_threadFunc, lp, pathToFifo);
    }

    void wait()
    {
        receiveOnly!DoneMessage();
    }

    void start(uint firstLine, uint lastLine)
    {
        m_tid.send(StartMessage(firstLine, lastLine));
    }

    void exit()
    {
        m_tid.send(ExitMessage());
    }

    static void _threadFunc(shared ILineProvider lp, string pathToFifo)
    {
        scope(exit) if(logging) writefln("FifoWriter(%s): Exiting _threadFunc", pathToFifo);

        try
        {
            const uint linesPerIteration = 100;
            bool done = false;

            while(!done)
            {
                receive(
                    (StartMessage msg) {
                        if(logging) writefln("FifoWriter(%s): received start command %d - %d", pathToFifo, msg.firstLine, msg.lastLine);

                        auto fifo = File(pathToFifo, "w");

                        uint line = msg.firstLine;
                        while(true)
                        {
                            uint lastLineOfIteration = line + linesPerIteration - 1;

                            /* If the last line is given, then check if we've reached it */
                            if(msg.lastLine != -1)
                            {
                                /* exit early if we've already sent everything that was requested */
                                if(line >= msg.lastLine)
                                {
                                    break;
                                }

                                /* don't send lines beyond the requested last line */
                                lastLineOfIteration = min(lastLineOfIteration, msg.lastLine);
                            }

                            auto lines = lp.get(line, lastLineOfIteration);

                            /* exit early if no more lines are available */
                            if(lines.isNull)
                            {
                                break;
                            }

                            if(logging) writefln("FifoWriter(%s): writing line %s: %s", pathToFifo, line, lines);
                            fifo.write(lines);

                            line = lastLineOfIteration + 1;
                        }

                        fifo.close();
                        ownerTid.send(DoneMessage());
                    },
                    (ExitMessage msg) {
                        if(logging) writefln("FifoWriter(%s): received exit command", pathToFifo);
                        done = true;
                    }
                );
            }
        }
        catch(Exception e)
        {
            writefln("FifoWriter(%s): exiting _threadFunc because of an exception: %s", pathToFifo, e);
        }
        catch(Error e)
        {
            writefln("FifoWriter(%s): exiting _threadFunc because of an error: %s", pathToFifo, e);
        }
    }
}
