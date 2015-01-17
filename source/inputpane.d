import std.algorithm;
import std.math;
import std.stdio;
import std.string;
import std.typecons;

import deimos.ncurses.curses;

import icontentprovider;
import myassert;

class InputPane
{
private:
    int m_x;
    int m_y;
    int m_width;
    int m_height;
    int m_maxScrollPositionX;
    int m_maxScrollPositionY;
    IContentProvider m_cp;

    WINDOW *m_pad;

    int m_scrollPositionX = 0;
    int m_scrollPositionY = 0;

public:
    this(int x, int y,
         int width, int height,
         int maxScrollPositionX, int maxScrollPositionY,
         IContentProvider cp)
    {
        m_cp = cp;

        m_x = x;
        m_y = y;
        m_width = width;
        m_height = height;
        m_maxScrollPositionX = maxScrollPositionX;
        m_maxScrollPositionY = maxScrollPositionY;

        m_pad = newpad(height, m_cp.getContentWidth());

        drawMissingLines(0, 0, height);
    }

    void drawMissingLines(int contentLineOffset, int displayLineOffset, int count)
    {
        int firstLine = contentLineOffset;
        int lastLine = contentLineOffset + count - 1;

        wmove(m_pad, displayLineOffset, 0);
        for(int i = firstLine; i <= lastLine; i++)
        {
            auto line = m_cp.get(i);
            if(line.isNull)
            {
                line = "\n";
            }
            wprintw(m_pad, toStringz(line));
        }
    }

    void scrollX(int n)
    {
        if(n > 0)
        {
            auto max_n = m_maxScrollPositionX - m_scrollPositionX;
            n = min(max_n, n);
        }
        else
        {
            auto min_n = -m_scrollPositionX;
            n = max(min_n, n);
        }

        m_scrollPositionX += n;
    }

    void scrollY(int n)
    {
        int missingLinesOffset;
        int missingLinesCount;

        if(n > 0)
        {
            auto max_n = m_maxScrollPositionY - m_scrollPositionY;
            n = min(max_n, n);

            missingLinesCount = min(n, m_height);
            missingLinesOffset = m_height - missingLinesCount;
        }
        else
        {
            auto min_n = -m_scrollPositionY;
            n = max(min_n, n);

            missingLinesCount = min(abs(n), m_height);
            missingLinesOffset = 0;
        }

        m_scrollPositionY += n;

        scrollok(m_pad, true);
        wscrl(m_pad, n);
        scrollok(m_pad, false);

        drawMissingLines(m_scrollPositionY + missingLinesOffset, missingLinesOffset, missingLinesCount);
    }


    /* Redraws content */
    void redraw()
    {
        prefresh(m_pad, 0, m_scrollPositionX, m_y, m_x, m_y + m_height - 1, m_x + m_width - 1);
    }
}

