import std.algorithm;
import std.math;
import std.string;
import std.typecons;

import deimos.ncurses.curses;

import myassert;

class InputPane
{
private:
    int m_scrollPosition = 0;

    int m_windowX;
    int m_windowY;
    int m_windowWidth;
    int m_windowHeight;
    WINDOW *m_window;

    int m_padX;
    int m_padY;
    int m_padWidth;
    int m_padHeight;
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

        m_window = newwin(height, width, y, x);

        m_padX = x + 1;
        m_padY = y + 1;
        m_padWidth = width - 2;
        m_padHeight = height - 2;

        m_pad = newpad(m_padHeight, m_padWidth);

        m_contentWidth = contentWidth;
        m_contentHeight = contentHeight;

        m_missingLinesOffset = 0;
        m_missingLinesCount = m_padHeight;
    }

    int getMaxScrollPosition()
    {
        return m_contentHeight - m_padHeight;
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
        return tuple(m_scrollPosition + m_missingLinesOffset, m_missingLinesCount);
    }

    void addMissingLine(int position, string line)
    {
        assert(m_updatingMissingLines);
        assert(m_missingLinesCount > 0);

        assertEqual(position, m_scrollPosition + m_missingLinesOffset);

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

    void scrollY(int n)
    {
        assert(m_missingLinesCount == 0);


        if(n > 0)
        {
            auto max_n = getMaxScrollPosition() - m_scrollPosition;
            n = min(max_n, n);

            m_missingLinesCount = min(n, m_padHeight);
            m_missingLinesOffset = m_padHeight - m_missingLinesCount;
            m_scrollPosition += n;
        }
        else
        {
            auto min_n = -m_scrollPosition;
            n = max(min_n, n);

            m_missingLinesCount = min(abs(n), m_padHeight);
            m_missingLinesOffset = 0;
            m_scrollPosition += n;
        }

        scrollok(m_pad, true);
        wscrl(m_pad, n);
        scrollok(m_pad, false);
    }

    void setPosition(int posX, int posY)
    {
        scrollY(posY - m_scrollPosition);
    }

    /* Redraws content */
    void redraw()
    {
        assert(m_missingLinesCount == 0);
        assert(!m_updatingMissingLines);

        prefresh(m_pad, 0, 0, m_padY, m_padX, m_padY + m_padHeight - 1, m_padX + m_padWidth - 1);
    }

    /* Redraws content and border */
    void redrawAll()
    {
        box(m_window, 0, 0);
        wrefresh(m_window);

        redraw();
    }
}

