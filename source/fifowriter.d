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
