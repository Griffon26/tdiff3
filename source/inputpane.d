import std.algorithm;
import std.math;
import std.string;
import std.typecons;

import deimos.ncurses.curses;

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

    int m_contentWidth;
    int m_contentHeight;

    /* To indicate which part of the pad needs to be filled with content.
     * Initially this is the entire pad, but usually it is only the part that
     * scrolled into view.
     */
    int m_missingLinesOffset;
    int m_missingLinesCount;
    bool m_updatingMissingLines = false;

public:
    this(int x, int y, int width, int height, int contentWidth, int contentHeight)
    {
        m_windowX = x;
        m_windowY = y;
        m_windowWidth = width;
        m_windowHeight = height;
        m_contentWidth = contentWidth;
        m_contentHeight = contentHeight;

        m_window = newwin(height, width, y, x);

        m_viewWidth = width - 2;
        m_viewHeight = height - 2;

        m_padX = x + 1;
        m_padY = y + 1;

        m_pad = newpad(m_viewHeight, m_contentWidth);

        m_missingLinesOffset = 0;
        m_missingLinesCount = m_viewHeight;
    }

    int getMaxScrollPositionX()
    {
        return m_contentWidth - m_viewWidth;
    }

    int getMaxScrollPositionY()
    {
        return m_contentHeight - m_viewHeight;
    }

    auto beginMissingLineUpdate()
    {
        assert(!m_updatingMissingLines);
        m_updatingMissingLines = true;

        /* Set the cursor position to the first missing line now, so the
         * missing lines (with newlines) can be printed without having to deal
         * with cursor positions for every line
         */
        wmove(m_pad, m_missingLinesOffset, 0);
        return tuple(m_scrollPositionY + m_missingLinesOffset, m_missingLinesCount);
    }

    void addMissingLine(int position, string line)
    {
        assert(m_updatingMissingLines);
        assert(m_missingLinesCount > 0);

        assertEqual(position, m_scrollPositionY + m_missingLinesOffset);

        wprintw(m_pad, toStringz(line));

        m_missingLinesOffset++;
        m_missingLinesCount--;
    }

    void endMissingLineUpdate()
    {
        assert(m_updatingMissingLines);
        m_updatingMissingLines = false;

        assert(m_missingLinesCount == 0);
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

    void scrollY(int n)
    {
        assert(m_missingLinesCount == 0);


        if(n > 0)
        {
            auto max_n = getMaxScrollPositionY() - m_scrollPositionY;
            n = min(max_n, n);

            m_missingLinesCount = min(n, m_viewHeight);
            m_missingLinesOffset = m_viewHeight - m_missingLinesCount;
            m_scrollPositionY += n;
        }
        else
        {
            auto min_n = -m_scrollPositionY;
            n = max(min_n, n);

            m_missingLinesCount = min(abs(n), m_viewHeight);
            m_missingLinesOffset = 0;
            m_scrollPositionY += n;
        }

        scrollok(m_pad, true);
        wscrl(m_pad, n);
        scrollok(m_pad, false);
    }

    void setPosition(int posX, int posY)
    {
        scrollY(posY - m_scrollPositionY);
    }

    /* Redraws content */
    void redraw()
    {
        assert(m_missingLinesCount == 0);
        assert(!m_updatingMissingLines);

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

