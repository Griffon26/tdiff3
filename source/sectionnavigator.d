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
module sectionnavigator;

import common;
import contentmapper;
import highlightaddingcontentprovider;

/**
 * The SectionNavigator is responsible for keeping track of the currently
 * selected merge result section. It tells the HighlightAddingContentProviders
 * which lines to highlight based on the selection.
 *
 * <object data="../uml/sectionnavigator.svg" type="image/svg+xml"></object>
 */
/*
 * @startuml
 * hide circle
 * skinparam minClassWidth 70
 * skinparam classArrowFontSize 8
 * class Ui --> SectionNavigator: sends section toggle commands\ngets focus position
 * SectionNavigator --> ContentMapper: requests section location\ntoggles sections
 * SectionNavigator --> "1" HighlightAddingContentProvider: sets output lines to be highlighted
 * SectionNavigator --> "3" HighlightAddingContentProvider: sets input lines to be highlighted
 *
 * url of Ui is [[../ui/Ui.html]]
 * url of HighlightAddingContentProvider is [[../highlightaddingcontentprovider/HighlightAddingContentProvider.html]]
 * url of ContentMapper is [[../contentmapper/ContentMapper.html]]
 * @enduml
 */
class SectionNavigator
{
private:
    int m_selectedSection;

    HighlightAddingContentProvider[3] m_d3cps;
    HighlightAddingContentProvider m_mcp;
    ContentMapper m_contentMapper;

    bool m_inputFocusChanged;
    bool m_outputFocusChanged;
    Position m_inputFocusPosition;
    Position m_outputFocusPosition;

public:
    this(HighlightAddingContentProvider[3] diff3ContentProviders, HighlightAddingContentProvider mergeResultContentProvider, ContentMapper contentMapper)
    {
        m_d3cps = diff3ContentProviders;
        m_mcp = mergeResultContentProvider;
        m_contentMapper = contentMapper;
    }

    private void setSelectedSection(int sectionIndex)
    {
        m_selectedSection = sectionIndex;

        auto sectionInfo = m_contentMapper.getSectionInfo(sectionIndex);
        foreach(cp; m_d3cps)
        {
            cp.setHighlight(sectionInfo.inputPaneLineNumbers);
        }
        m_mcp.setHighlight(sectionInfo.mergeResultPaneLineNumbers);
        updateInputFocusPosition(Position(sectionInfo.inputPaneLineNumbers.firstLine, 0));
        updateOutputFocusPosition(Position(sectionInfo.mergeResultPaneLineNumbers.firstLine, 0));
    }

    /* Editor operations */
    void selectNextDifference()
    {
        int sectionIndex = m_contentMapper.findNextDifference(m_selectedSection);
        if(sectionIndex != -1)
        {
            setSelectedSection(sectionIndex);
        }
    }

    void selectPreviousDifference()
    {
        int sectionIndex = m_contentMapper.findPreviousDifference(m_selectedSection);
        if(sectionIndex != -1)
        {
            setSelectedSection(sectionIndex);
        }
    }

    void selectNextUnsolvedDifference()
    {
        int sectionIndex = m_contentMapper.findNextUnsolvedDifference(m_selectedSection);
        if(sectionIndex != -1)
        {
            setSelectedSection(sectionIndex);
        }
    }

    void selectPreviousUnsolvedDifference()
    {
        int sectionIndex = m_contentMapper.findPreviousUnsolvedDifference(m_selectedSection);
        if(sectionIndex != -1)
        {
            setSelectedSection(sectionIndex);
        }
    }

    void toggleCurrentSectionSource(LineSource lineSource)
    {
        m_contentMapper.toggleSectionSource(m_selectedSection, lineSource);
        setSelectedSection(m_selectedSection);
    }

    /**
     * the focus position represents the position in input and output content
     * that should be moved into view. If the last operation was an edit, then
     * this is the cursor position. If the last operation was a change in
     * selected section, then it's the first character in the section.
     * Only when the focus position changes should the scroll position be
     * updated.
     */
    private void updateInputFocusPosition(Position pos)
    {
        m_inputFocusChanged = true;
        m_inputFocusPosition = pos;
    }

    private void updateOutputFocusPosition(Position pos)
    {
        m_outputFocusChanged = true;
        m_outputFocusPosition = pos;
    }

    bool inputFocusNeedsUpdate()
    {
        return m_inputFocusChanged;
    }

    bool outputFocusNeedsUpdate()
    {
        return m_outputFocusChanged;
    }

    Position getInputFocusPosition()
    {
        m_inputFocusChanged = false;
        return m_inputFocusPosition;
    }

    Position getOutputFocusPosition()
    {
        m_outputFocusChanged = false;
        return m_outputFocusPosition;
    }
}

