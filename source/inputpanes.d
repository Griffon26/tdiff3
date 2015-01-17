import core.thread;
import std.algorithm;
import std.conv;
import std.math;
import std.stdio;
import std.string;
import std.typecons;

import deimos.ncurses.curses;

import icontentprovider;
import inputpane;
import myassert;

class InputPanes
{
private:
    int m_scrollPositionX = 0;
    int m_scrollPositionY = 0;

    InputPane[3] m_inputPanes;

    int scrollBarWidth = 1;
    int borderWidth = 1;
    int diffStatusWidth = 1;
    int nrOfPanes = 3;

    int m_inputPaneHeight;

    int m_maxScrollPositionX;
    int m_maxScrollPositionY;

public:
    this(int x, int y, int width, int height, IContentProvider[3] cps)
    {
        assert(cps[0].getContentHeight() == cps[1].getContentHeight() &&
               cps[0].getContentHeight() == cps[2].getContentHeight());

        int lineNumberWidth = to!int(trunc(log10(cps[0].getContentHeight()))) + 1;

        /* Draw a box around the input panes */
        mvhline(y, x, ACS_HLINE, width - 1);
        mvvline(y, x, ACS_VLINE, height - 1);
        mvhline(y + height - 1, x, ACS_HLINE, width - 1);
        mvvline(y, x + width - 1, ACS_VLINE, height - 1);

        mvaddch(y, x, ACS_ULCORNER);
        mvaddch(y, x + width - 1, ACS_URCORNER);
        mvaddch(y + height - 1, x, ACS_LLCORNER);
        mvaddch(y + height - 1, x + width - 1, ACS_LRCORNER);

        int summedPaneWidth = width - scrollBarWidth -
                              nrOfPanes * (borderWidth + lineNumberWidth + diffStatusWidth) -
                              borderWidth;
        m_inputPaneHeight = height - 2 * borderWidth;

        int remainingPaneWidth = summedPaneWidth;
        int paneOffset = x;
        for(int i = 0; i < nrOfPanes; i++)
        {
            int paneWidth = remainingPaneWidth / (nrOfPanes - i);

            /* Draw borders before the second and third pane */
            if(i != 0)
            {
                mvaddch(y, paneOffset, ACS_TTEE);
                mvaddch(y + height - 1, paneOffset, ACS_BTEE);
                mvvline(y + 1, paneOffset, ACS_VLINE, height - 2);
            }

            paneOffset += borderWidth + lineNumberWidth + diffStatusWidth;

            m_inputPanes[i] = new InputPane(paneOffset, y + 1, paneWidth, m_inputPaneHeight, cps[i]);

            paneOffset += paneWidth;

            remainingPaneWidth -= paneWidth;
        }

        m_maxScrollPositionX = cps[0].getContentWidth() - (summedPaneWidth + 2) / 3;
        m_maxScrollPositionY = cps[0].getContentHeight() - m_inputPaneHeight;
    }

    int getMaxScrollPositionX()
    {
        return m_maxScrollPositionX;
    }

    int getMaxScrollPositionY()
    {
        return m_maxScrollPositionY;
    }

    void scrollX(int n)
    {
        if(n > 0)
        {
            auto max_n = getMaxScrollPositionX() - m_scrollPositionX;
            n = min(max_n, n);
        }
        else
        {
            auto min_n = -m_scrollPositionX;
            n = max(min_n, n);
        }

        m_scrollPositionX += n;
        foreach(ip; m_inputPanes)
        {
            ip.scrollX(n);
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

            missingLinesCount = min(n, m_inputPaneHeight);
            missingLinesOffset = m_inputPaneHeight - missingLinesCount;
        }
        else
        {
            auto min_n = -m_scrollPositionY;
            n = max(min_n, n);

            missingLinesCount = min(abs(n), m_inputPaneHeight);
            missingLinesOffset = 0;
        }

        m_scrollPositionY += n;
        foreach(ip; m_inputPanes)
        {
            ip.scrollY(n);
            ip.drawMissingLines(m_scrollPositionY + missingLinesOffset, missingLinesOffset, missingLinesCount);
        }
    }

    /* Redraws content */
    void redraw()
    {
        foreach(ip; m_inputPanes)
        {
            ip.redraw();
        }
    }

}

