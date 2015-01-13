import std.algorithm;
import std.math;
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

    int m_windowX;
    int m_windowY;
    int m_windowWidth;
    int m_windowHeight;
    WINDOW *m_window;

    int m_viewWidth;
    int m_viewHeight;

    int m_padX;
    int m_padY;
    WINDOW *m_pad;

    IContentProvider m_cp;

public:
    this(int x, int y, int width, int height, IContentProvider cp)
    {
        m_windowX = x;
        m_windowY = y;
        m_windowWidth = width;
        m_windowHeight = height;
        m_cp = cp;

        m_window = newwin(height, width, y, x);

        m_viewWidth = width - 2;
        m_viewHeight = height - 2;

        m_padX = x + 1;
        m_padY = y + 1;

        m_pad = newpad(m_viewHeight, m_cp.getContentWidth());

        drawMissingLines(0, m_viewHeight);
    }

    int getMaxScrollPositionX()
    {
        return m_cp.getContentWidth() - m_viewWidth;
    }

    int getMaxScrollPositionY()
    {
        return m_cp.getContentHeight() - m_viewHeight;
    }

    void scrollX(int n)
    {
        if(n > 0)
        {
            auto max_n = getMaxScrollPositionX() - m_scrollPositionX;
            n = min(max_n, n);

            m_scrollPositionX += n;
        }
        else
        {
            auto min_n = -m_scrollPositionX;
            n = max(min_n, n);

            m_scrollPositionX += n;
        }
    }

    private void drawMissingLines(int missingLinesOffset, int missingLinesCount)
    {
        int firstLine = m_scrollPositionY + missingLinesOffset;
        int lastLine = firstLine + missingLinesCount - 1;

        wmove(m_pad, missingLinesOffset, 0);
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
        int missingLinesOffset;
        int missingLinesCount;

        if(n > 0)
        {
            auto max_n = getMaxScrollPositionY() - m_scrollPositionY;
            n = min(max_n, n);

            missingLinesCount = min(n, m_viewHeight);
            missingLinesOffset = m_viewHeight - missingLinesCount;
            m_scrollPositionY += n;
        }
        else
        {
            auto min_n = -m_scrollPositionY;
            n = max(min_n, n);

            missingLinesCount = min(abs(n), m_viewHeight);
            missingLinesOffset = 0;
            m_scrollPositionY += n;
        }

        scrollok(m_pad, true);
        wscrl(m_pad, n);
        scrollok(m_pad, false);

        drawMissingLines(missingLinesOffset, missingLinesCount);
    }

    void setPosition(int posX, int posY)
    {
        scrollY(posY - m_scrollPositionY);
    }

    /* Redraws content */
    void redraw()
    {
        prefresh(m_pad, 0, m_scrollPositionX, m_padY, m_padX, m_padY + m_viewHeight - 1, m_padX + m_viewWidth - 1);
    }

    /* Redraws content and border */
    void redrawAll()
    {
        box(m_window, 0, 0);
        wrefresh(m_window);

        redraw();
    }
}

