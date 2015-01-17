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
    int m_scrollPositionX = 0;
    int m_scrollPositionY = 0;

    int m_x;
    int m_y;
    int m_width;
    int m_height;
    WINDOW *m_pad;

    IContentProvider m_cp;

public:
    this(int x, int y, int width, int height, IContentProvider cp)
    {
        m_cp = cp;

        m_x = x;
        m_y = y;
        m_width = width;
        m_height = height;

        m_pad = newpad(height, m_cp.getContentWidth());

        drawMissingLines(0, 0, height);
    }

    void scrollX(int n)
    {
        m_scrollPositionX += n;
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

    void scrollY(int n)
    {
        m_scrollPositionY += n;

        scrollok(m_pad, true);
        wscrl(m_pad, n);
        scrollok(m_pad, false);
    }

    /* Redraws content */
    void redraw()
    {
        prefresh(m_pad, 0, m_scrollPositionX, m_y, m_x, m_y + m_height - 1, m_x + m_width - 1);
    }
}

